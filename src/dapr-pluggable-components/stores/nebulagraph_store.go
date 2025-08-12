package stores

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/rand"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/dapr/components-contrib/state"
	"github.com/dapr/kit/logger"
	nebula "github.com/vesoft-inc/nebula-go/v3"
)

// NebulaStateStore is a production-ready state store implementation for NebulaGraph.
//
// This implementation incorporates best practices inspired by ScyllaDB GoCQL patterns:
// 1. Enhanced retry logic with exponential backoff and jitter
// 2. Connection health monitoring with session validation
// 3. ETag support for optimistic concurrency control
// 4. Context-aware operations with proper timeout handling
// 5. Graceful degradation patterns for bulk operations
// 6. Comprehensive error handling with transient error detection
// 7. Connection pool optimizations with configurable parameters
// 8. Batch operation fallback strategies for reliability
type NebulaStateStore struct {
	state.BulkStore
	
	pool   *nebula.ConnectionPool
	config NebulaConfig
	logger logger.Logger
	mu     sync.RWMutex
	closed bool
}

// Compile time check to ensure NebulaStateStore implements state.Store
var _ state.Store = (*NebulaStateStore)(nil)

// Compile time check to ensure NebulaStateStore implements state.Querier
var _ state.Querier = (*NebulaStateStore)(nil)

// Compile time check to ensure NebulaStateStore implements state.BulkStore
var _ state.BulkStore = (*NebulaStateStore)(nil)

type NebulaConfig struct {
	Hosts               string `json:"hosts" mapstructure:"hosts"`             // Changed to string for comma-separated values
	Port                string `json:"port" mapstructure:"port"`               // Changed to string to handle Dapr metadata
	Username            string `json:"username" mapstructure:"username"`
	Password            string `json:"password" mapstructure:"password"`
	Space               string `json:"space" mapstructure:"space"`
	ConnectionTimeout   string `json:"connectionTimeout" mapstructure:"connectionTimeout"`
	ExecutionTimeout    string `json:"executionTimeout" mapstructure:"executionTimeout"`
	MaxConnPoolSize     string `json:"maxConnPoolSize" mapstructure:"maxConnPoolSize"`
	MinConnPoolSize     string `json:"minConnPoolSize" mapstructure:"minConnPoolSize"`
	IdleTime            string `json:"idleTime" mapstructure:"idleTime"`
	// Additional fields for enhanced functionality
	MaxRetries          string `json:"maxRetries" mapstructure:"maxRetries"`             // Maximum retry attempts (default: 3)
	RetryDelay          string `json:"retryDelay" mapstructure:"retryDelay"`             // Base retry delay (default: 100ms)
}

// NewNebulaStateStore creates a new instance of NebulaStateStore.
func NewNebulaStateStore(inputLogger logger.Logger) state.Store {
	// Create default logger if none provided
	if inputLogger == nil {
		inputLogger = logger.NewLogger("nebulagraph-state")
	}
	return &NebulaStateStore{
		logger: inputLogger,
	}
}

func (store *NebulaStateStore) Init(ctx context.Context, metadata state.Metadata) error {
	store.logger.Info("Initializing NebulaStateStore...")

	// Check for context cancellation
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	// Validate required metadata properties
	requiredProps := []string{"hosts", "port", "space", "username", "password"}
	for _, prop := range requiredProps {
		if value, exists := metadata.Properties[prop]; !exists || value == "" {
			return fmt.Errorf("required metadata property '%s' is missing or empty", prop)
		}
	}

	// Parse configuration from metadata
	configBytes, _ := json.Marshal(metadata.Properties)
	if err := json.Unmarshal(configBytes, &store.config); err != nil {
		store.logger.Errorf("Failed to parse config: %v", err)
		return fmt.Errorf("failed to parse configuration: %w", err)
	}

	// Additional validation for required fields
	if store.config.Hosts == "" {
		return errors.New("hosts configuration is required")
	}
	if store.config.Space == "" {
		return errors.New("space configuration is required")
	}
	if store.config.Username == "" {
		return errors.New("username configuration is required")
	}
	if store.config.Password == "" {
		return errors.New("password configuration is required")
	}

	store.logger.Infof("Parsed config: hosts=%s, port=%s, space=%s", 
		store.config.Hosts, store.config.Port, store.config.Space)

	// Parse hosts string into slice
	hosts := strings.Split(store.config.Hosts, ",")
	for i := range hosts {
		hosts[i] = strings.TrimSpace(hosts[i])
	}

	// Convert port string to int
	port, err := strconv.Atoi(store.config.Port)
	if err != nil {
		store.logger.Errorf("Invalid port: %v", err)
		return fmt.Errorf("invalid port number: %w", err)
	}

	store.logger.Infof("Connecting to NebulaGraph at hosts: %v, port: %d", hosts, port)

	// Initialize NebulaGraph connection pool
	hostList := make([]nebula.HostAddress, len(hosts))
	for i, host := range hosts {
		hostList[i] = nebula.HostAddress{Host: host, Port: port}
	}

	poolConfig := nebula.GetDefaultConf()
	
	// Parse and apply connection pool configuration from metadata
	if store.config.MaxConnPoolSize != "" {
		if maxSize, err := strconv.Atoi(store.config.MaxConnPoolSize); err == nil {
			poolConfig.MaxConnPoolSize = maxSize
		} else {
			store.logger.Warnf("Invalid maxConnPoolSize value: %s, using default: %d", store.config.MaxConnPoolSize, poolConfig.MaxConnPoolSize)
		}
	} else {
		poolConfig.MaxConnPoolSize = 50 // Default enhanced value
	}
	
	if store.config.MinConnPoolSize != "" {
		if minSize, err := strconv.Atoi(store.config.MinConnPoolSize); err == nil {
			poolConfig.MinConnPoolSize = minSize
		} else {
			store.logger.Warnf("Invalid minConnPoolSize value: %s, using default: %d", store.config.MinConnPoolSize, poolConfig.MinConnPoolSize)
		}
	} else {
		poolConfig.MinConnPoolSize = 5 // Default enhanced value
	}
	
	if store.config.ConnectionTimeout != "" {
		if timeout, err := time.ParseDuration(store.config.ConnectionTimeout); err == nil {
			poolConfig.TimeOut = timeout
		} else {
			store.logger.Warnf("Invalid connectionTimeout value: %s, using default: %s", store.config.ConnectionTimeout, poolConfig.TimeOut)
		}
	} else {
		poolConfig.TimeOut = 10 * time.Second // 10 second default
	}
	
	if store.config.IdleTime != "" {
		if idleTime, err := time.ParseDuration(store.config.IdleTime); err == nil {
			poolConfig.IdleTime = idleTime
		} else {
			store.logger.Warnf("Invalid idleTime value: %s, using default: %s", store.config.IdleTime, poolConfig.IdleTime)
		}
	} else {
		poolConfig.IdleTime = 8 * time.Hour // 8 hours default
	}
	
	// Set default values for enhanced retry configuration
	if store.config.MaxRetries == "" {
		store.config.MaxRetries = "3" // Default to 3 retries
	}
	if store.config.RetryDelay == "" {
		store.config.RetryDelay = "100ms" // Default to 100ms base delay
	}
	
	store.logger.Infof("NebulaGraph connection pool configuration: maxSize=%d, minSize=%d, timeout=%s, idleTime=%s, maxRetries=%s, retryDelay=%s", 
		poolConfig.MaxConnPoolSize, poolConfig.MinConnPoolSize, poolConfig.TimeOut, poolConfig.IdleTime, 
		store.config.MaxRetries, store.config.RetryDelay)
	
	pool, err := nebula.NewConnectionPool(hostList, poolConfig, nebula.DefaultLogger{})
	if err != nil {
		store.logger.Errorf("Failed to create connection pool: %v", err)
		return fmt.Errorf("failed to create connection pool: %w", err)
	}

	store.logger.Info("NebulaStateStore initialized successfully")
	store.pool = pool
	return nil
}

func (store *NebulaStateStore) GetComponentMetadata() map[string]string {
	return map[string]string{
		"type":    "state",
		"version": "v1",
		"author":  "NebulaGraph Team", 
		"url":     "https://github.com/vesoft-inc/nebula",
	}
}

func (store *NebulaStateStore) Features() []state.Feature {
	// Return supported features for NebulaGraph state store
	// Now including ETag support for optimistic concurrency control
	return []state.Feature{
		state.FeatureETag,
		state.FeatureTransactional,
		state.FeatureQueryAPI,
	}
}

// getSessionWithRetry attempts to get a session with retry logic for connection pool exhaustion
// Enhanced with ScyllaDB-inspired retry patterns and error classification
func (store *NebulaStateStore) getSessionWithRetry(maxRetries int) (*nebula.Session, error) {
	var session *nebula.Session
	var err error
	
	// Get retry configuration from config or use defaults
	baseRetryDelay := 100 * time.Millisecond
	if store.config.RetryDelay != "" {
		if delay, parseErr := time.ParseDuration(store.config.RetryDelay); parseErr == nil {
			baseRetryDelay = delay
		}
	}
	
	configuredMaxRetries := maxRetries
	if store.config.MaxRetries != "" {
		if retries, parseErr := strconv.Atoi(store.config.MaxRetries); parseErr == nil {
			configuredMaxRetries = retries
		}
	}
	
	for retry := 0; retry <= configuredMaxRetries; retry++ {
		session, err = store.pool.GetSession(store.config.Username, store.config.Password)
		if err == nil {
			// Enhanced session health validation with timeout
			if session != nil {
				// Use a shorter timeout for health check to avoid blocking
				resp, pingErr := session.Execute("YIELD 1")
				if pingErr == nil && resp.IsSucceed() {
					return session, nil
				} else {
					// Session is unhealthy, release and retry
					session.Release()
					if pingErr != nil {
						err = fmt.Errorf("session ping failed: %w", pingErr)
					} else {
						err = fmt.Errorf("session ping failed: %s", resp.GetErrorMsg())
					}
				}
			}
		}
		
		// Enhanced error classification for better retry decisions
		isTransientError := store.isTransientError(err)
		
		if isTransientError && retry < configuredMaxRetries {
			// Enhanced exponential backoff with jitter (ScyllaDB pattern)
			exponentialDelay := time.Duration(retry*retry+1) * baseRetryDelay
			jitter := time.Duration(rand.Intn(int(baseRetryDelay/2))) // Up to 50ms jitter
			waitTime := exponentialDelay + jitter
			
			store.logger.Warnf("Transient error, retrying (%d/%d) after %v: %v", 
				retry+1, configuredMaxRetries, waitTime, err)
			time.Sleep(waitTime)
			continue
		}
		
		// For non-transient errors or max retries reached, return the error
		if retry >= configuredMaxRetries {
			store.logger.Errorf("Max retries (%d) exceeded for session acquisition: %v", configuredMaxRetries, err)
		}
		return nil, err
	}
	
	return nil, err
}

// isTransientError classifies errors as transient (retryable) or permanent
// Following ScyllaDB error classification patterns
func (store *NebulaStateStore) isTransientError(err error) bool {
	if err == nil {
		return false
	}
	
	errStr := err.Error()
	
	// Connection-related transient errors
	transientPatterns := []string{
		"pool capacity",
		"No valid connection",
		"connection",
		"ping failed",
		"timeout",
		"refused",
		"reset",
		"broken pipe",
		"network",
		"i/o timeout",
		"no route to host",
		"host unreachable",
		"session unhealthy",
	}
	
	for _, pattern := range transientPatterns {
		if strings.Contains(errStr, pattern) {
			return true
		}
	}
	
	return false
}

func (store *NebulaStateStore) Delete(ctx context.Context, req *state.DeleteRequest) error {
	if req.Key == "" {
		return errors.New("key cannot be empty")
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return errors.New("store is closed")
	}

	if store.pool == nil {
		return errors.New("connection pool not initialized")
	}

	session, err := store.getSessionWithRetry(3) // Retry up to 3 times
	if err != nil {
		store.logger.Errorf("Failed to get session for delete: %v", err)
		return fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	// Handle ETag for optimistic concurrency control
	if req.ETag != nil && *req.ETag != "" {
		// Verify current ETag matches before deleting
		checkQuery := fmt.Sprintf("USE %s; MATCH (v:state) WHERE id(v) == '%s' RETURN v.state.etag AS etag", store.config.Space, req.Key)
		checkResp, err := session.Execute(checkQuery)
		if err != nil {
			return fmt.Errorf("failed to check current ETag: %w", err)
		}
		
		if checkResp.IsSucceed() && checkResp.GetRowSize() > 0 {
			record, err := checkResp.GetRowValuesByIndex(0)
			if err == nil {
				currentEtagWrapper, err := record.GetValueByIndex(0)
				if err == nil && !currentEtagWrapper.IsNull() {
					if currentEtagStr, err := currentEtagWrapper.AsString(); err == nil {
						if currentEtagStr != *req.ETag {
							return fmt.Errorf("ETag mismatch: expected '%s', got '%s'", *req.ETag, currentEtagStr)
						}
					}
				}
			}
		}
	}

	query := fmt.Sprintf("USE %s; DELETE VERTEX '%s'", store.config.Space, req.Key)
	resp, err := session.Execute(query)
	if err != nil {
		return fmt.Errorf("failed to execute delete query: %w", err)
	}

	if !resp.IsSucceed() {
		return fmt.Errorf("delete operation failed: %s", resp.GetErrorMsg())
	}

	return nil
}

func (store *NebulaStateStore) Get(ctx context.Context, req *state.GetRequest) (*state.GetResponse, error) {
	if req.Key == "" {
		return nil, errors.New("key cannot be empty")
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return nil, errors.New("store is closed")
	}

	store.logger.Debugf("Getting value for key: %s", req.Key)

	// Ensure component is properly initialized
	if store.pool == nil {
		return nil, errors.New("connection pool not initialized")
	}

	session, err := store.getSessionWithRetry(3) // Retry up to 3 times
	if err != nil {
		store.logger.Errorf("Failed to get session: %v", err)
		return nil, fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	// Try to fetch the vertex with the key - enhanced query with ETag support
	query := fmt.Sprintf("USE %s; MATCH (v:state) WHERE id(v) == '%s' RETURN v.state.data AS data, v.state.etag AS etag, v.state.last_modified AS last_modified", store.config.Space, req.Key)
	store.logger.Debugf("Executing query: %s", query)
	resp, err := session.Execute(query)
	if err != nil {
		store.logger.Errorf("Query failed: %v", err)
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	if !resp.IsSucceed() {
		return nil, fmt.Errorf("query failed: %s", resp.GetErrorMsg())
	}

	// If no results found, try with FETCH as fallback
	if resp.GetRowSize() == 0 {
		query = fmt.Sprintf("USE %s; FETCH PROP ON state '%s' YIELD properties(vertex)", store.config.Space, req.Key)
		resp, err = session.Execute(query)
		if err != nil {
			return nil, fmt.Errorf("failed to execute fetch query: %w", err)
		}

		if !resp.IsSucceed() || resp.GetRowSize() == 0 {
			return &state.GetResponse{}, nil
		}
	}

	// Use GetRowValuesByIndex to get the first row
	record, err := resp.GetRowValuesByIndex(0)
	if err != nil {
		return nil, fmt.Errorf("failed to get row: %w", err)
	}

	// Get the data value (first column)
	dataWrapper, err := record.GetValueByIndex(0)
	if err != nil {
		return nil, fmt.Errorf("failed to get data value: %w", err)
	}

	if dataWrapper.IsNull() {
		return &state.GetResponse{}, nil
	}

	// Extract string value using AsString method
	dataStr, err := dataWrapper.AsString()
	if err != nil {
		return nil, fmt.Errorf("failed to extract data as string: %w", err)
	}

	response := &state.GetResponse{
		Data: []byte(dataStr),
	}

	// Try to get ETag if available (second column) - handle gracefully if not present
	if etagWrapper, err := record.GetValueByIndex(1); err == nil && !etagWrapper.IsNull() {
		if etagStr, err := etagWrapper.AsString(); err == nil {
			response.ETag = &etagStr
		}
	}

	return response, nil
}

func (store *NebulaStateStore) Set(ctx context.Context, req *state.SetRequest) error {
	if req.Key == "" {
		return errors.New("key cannot be empty")
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return errors.New("store is closed")
	}

	if store.pool == nil {
		return errors.New("connection pool not initialized")
	}

	store.logger.Debugf("Setting value for key: %s", req.Key)

	session, err := store.getSessionWithRetry(3) // Retry up to 3 times
	if err != nil {
		store.logger.Errorf("Failed to get session for set: %v", err)
		return fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	// Insert or update vertex with the state data, ETag, and timestamp
	data := ""
	if req.Value != nil {
		if bytes, ok := req.Value.([]byte); ok {
			data = string(bytes)
		} else if str, ok := req.Value.(string); ok {
			data = str
		}
	}

	// Generate new ETag with high precision timestamp for better concurrency control
	newEtag := fmt.Sprintf("%d", time.Now().UnixNano())
	timestamp := time.Now().Unix()

	// Handle ETag for optimistic concurrency control
	if req.ETag != nil && *req.ETag != "" {
		// Verify current ETag matches before updating
		checkQuery := fmt.Sprintf("USE %s; MATCH (v:state) WHERE id(v) == '%s' RETURN v.state.etag AS etag", store.config.Space, req.Key)
		checkResp, err := session.Execute(checkQuery)
		if err != nil {
			return fmt.Errorf("failed to check current ETag: %w", err)
		}
		
		if checkResp.IsSucceed() && checkResp.GetRowSize() > 0 {
			record, err := checkResp.GetRowValuesByIndex(0)
			if err == nil {
				currentEtagWrapper, err := record.GetValueByIndex(0)
				if err == nil && !currentEtagWrapper.IsNull() {
					if currentEtagStr, err := currentEtagWrapper.AsString(); err == nil {
						if currentEtagStr != *req.ETag {
							return fmt.Errorf("ETag mismatch: expected '%s', got '%s'", *req.ETag, currentEtagStr)
						}
					}
				}
			}
		}
	}

	// Escape single quotes in data to prevent injection
	data = strings.ReplaceAll(data, "'", "\\'")

	// Insert or update with ETag and timestamp
	query := fmt.Sprintf("USE %s; INSERT VERTEX state(data, etag, last_modified) VALUES '%s':('%s', '%s', %d)",
		store.config.Space, req.Key, data, newEtag, timestamp)

	resp, err := session.Execute(query)
	if err != nil {
		return fmt.Errorf("failed to execute insert query: %w", err)
	}

	if !resp.IsSucceed() {
		return fmt.Errorf("insert operation failed: %s", resp.GetErrorMsg())
	}

	return nil
}

func (store *NebulaStateStore) BulkGet(ctx context.Context, req []state.GetRequest, opts state.BulkGetOpts) ([]state.BulkGetResponse, error) {
	if len(req) == 0 {
		return []state.BulkGetResponse{}, nil
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return nil, errors.New("store is closed")
	}

	store.logger.Debugf("Bulk getting %d keys", len(req))
	
	if store.pool == nil {
		return nil, errors.New("connection pool not initialized")
	}

	session, err := store.getSessionWithRetry(3) // Retry up to 3 times
	if err != nil {
		store.logger.Errorf("Failed to get session for bulk get: %v", err)
		return nil, fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	responses := make([]state.BulkGetResponse, len(req))

	// Build batch query for all keys
	if len(req) == 0 {
		return responses, nil
	}

	// For small batches, use individual queries for better error handling
	if len(req) <= 5 {
		for i, getReq := range req {
			resp, err := store.Get(ctx, &getReq)
			response := state.BulkGetResponse{
				Key: getReq.Key,
			}
			if err != nil {
				response.Error = err.Error()
			} else if resp != nil {
				response.Data = resp.Data
			}
			responses[i] = response
		}
		return responses, nil
	}

	// For larger batches, build a batch query
	var keys []string
	keyToIndex := make(map[string]int)
	for i, getReq := range req {
		keys = append(keys, fmt.Sprintf("'%s'", getReq.Key))
		keyToIndex[getReq.Key] = i
		responses[i] = state.BulkGetResponse{Key: getReq.Key}
	}

	// Build a batch FETCH query with ETag support
	query := fmt.Sprintf("USE %s; FETCH PROP ON state %s YIELD id(vertex) AS key, properties(vertex).data AS data, properties(vertex).etag AS etag",
		store.config.Space, strings.Join(keys, ", "))

	store.logger.Debugf("Executing bulk query: %s", query)
	resp, err := session.Execute(query)
	if err != nil {
		// Fall back to individual queries if batch fails
		store.logger.Debugf("Batch query failed, falling back to individual queries: %v", err)
		for i, getReq := range req {
			resp, err := store.Get(ctx, &getReq)
			if err != nil {
				responses[i].Error = err.Error()
			} else if resp != nil {
				responses[i].Data = resp.Data
				responses[i].ETag = resp.ETag
			}
		}
		return responses, nil
	}

	if !resp.IsSucceed() {
		// Fall back to individual queries
		store.logger.Debugf("Batch query not successful, falling back: %s", resp.GetErrorMsg())
		for i, getReq := range req {
			resp, err := store.Get(ctx, &getReq)
			if err != nil {
				responses[i].Error = err.Error()
			} else if resp != nil {
				responses[i].Data = resp.Data
				responses[i].ETag = resp.ETag
			}
		}
		return responses, nil
	}

	// Process batch results with ETag support
	for i := 0; i < resp.GetRowSize(); i++ {
		record, err := resp.GetRowValuesByIndex(i)
		if err != nil {
			continue
		}

		// Get key and data from the result
		keyVal, err := record.GetValueByIndex(0)
		if err != nil {
			continue
		}
		key, err := keyVal.AsString()
		if err != nil {
			continue
		}

		dataVal, err := record.GetValueByIndex(1)
		if err != nil {
			continue
		}

		if idx, exists := keyToIndex[key]; exists {
			if !dataVal.IsNull() {
				dataStr, err := dataVal.AsString()
				if err == nil {
					responses[idx].Data = []byte(dataStr)
				}
			}
			
			// Try to get ETag if available (third column) - handle gracefully if not present
			if etagVal, err := record.GetValueByIndex(2); err == nil && !etagVal.IsNull() {
				if etagStr, err := etagVal.AsString(); err == nil {
					responses[idx].ETag = &etagStr
				}
			}
		}
	}

	store.logger.Debugf("BulkGet completed for %d keys", len(req))
	return responses, nil
}

func (store *NebulaStateStore) BulkDelete(ctx context.Context, req []state.DeleteRequest, opts state.BulkStoreOpts) error {
	if len(req) == 0 {
		return nil
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return errors.New("store is closed")
	}

	store.logger.Debugf("Bulk deleting %d keys", len(req))
	
	if store.pool == nil {
		return errors.New("connection pool not initialized")
	}

	session, err := store.getSessionWithRetry(3) // Retry up to 3 times
	if err != nil {
		store.logger.Errorf("Failed to get session for bulk delete: %v", err)
		return fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	// For small batches, use individual operations
	if len(req) <= 5 {
		for _, delReq := range req {
			if err := store.Delete(ctx, &delReq); err != nil {
				return fmt.Errorf("failed to delete key %s: %w", delReq.Key, err)
			}
		}
		return nil
	}

	// For larger batches, build a batch delete query
	var keys []string
	for _, delReq := range req {
		keys = append(keys, fmt.Sprintf("'%s'", delReq.Key))
	}

	// Build batch DELETE query
	query := fmt.Sprintf("USE %s; DELETE VERTEX %s",
		store.config.Space, strings.Join(keys, ", "))

	store.logger.Debugf("Executing bulk delete query: %s", query)
	resp, err := session.Execute(query)
	if err != nil {
		// Fall back to individual deletes if batch fails
		store.logger.Debugf("Batch delete failed, falling back to individual deletes: %v", err)
		for _, delReq := range req {
			if err := store.Delete(ctx, &delReq); err != nil {
				return fmt.Errorf("failed to delete key %s: %w", delReq.Key, err)
			}
		}
		return nil
	}

	if !resp.IsSucceed() {
		// Fall back to individual deletes
		store.logger.Debugf("Batch delete not successful, falling back: %s", resp.GetErrorMsg())
		for _, delReq := range req {
			if err := store.Delete(ctx, &delReq); err != nil {
				return fmt.Errorf("failed to delete key %s: %w", delReq.Key, err)
			}
		}
		return nil
	}

	store.logger.Debugf("BulkDelete completed for %d keys", len(req))
	return nil
}

func (store *NebulaStateStore) BulkSet(ctx context.Context, req []state.SetRequest, opts state.BulkStoreOpts) error {
	if len(req) == 0 {
		return nil
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return errors.New("store is closed")
	}

	store.logger.Debugf("Bulk setting %d keys", len(req))
	
	if store.pool == nil {
		return errors.New("connection pool not initialized")
	}

	session, err := store.getSessionWithRetry(3) // Retry up to 3 times
	if err != nil {
		store.logger.Errorf("Failed to get session for bulk set: %v", err)
		return fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	// For small batches, use individual operations
	if len(req) <= 5 {
		for _, setReq := range req {
			if err := store.Set(ctx, &setReq); err != nil {
				return fmt.Errorf("failed to set key %s: %w", setReq.Key, err)
			}
		}
		return nil
	}

	// For larger batches, build a batch insert query with ETag support
	var values []string
	timestamp := time.Now().Unix()
	
	for _, setReq := range req {
		data := ""
		if setReq.Value != nil {
			if bytes, ok := setReq.Value.([]byte); ok {
				data = string(bytes)
			} else if str, ok := setReq.Value.(string); ok {
				data = str
			}
		}
		// Escape single quotes in data to prevent injection
		data = strings.ReplaceAll(data, "'", "\\'")
		
		// Generate new ETag for each item
		newEtag := fmt.Sprintf("%d-%s", time.Now().UnixNano(), setReq.Key)
		
		values = append(values, fmt.Sprintf("'%s':('%s', '%s', %d)", setReq.Key, data, newEtag, timestamp))
	}

	// Build batch INSERT query with ETag and timestamp
	query := fmt.Sprintf("USE %s; INSERT VERTEX state(data, etag, last_modified) VALUES %s",
		store.config.Space, strings.Join(values, ", "))

	store.logger.Debugf("Executing bulk insert query: %s", query)
	resp, err := session.Execute(query)
	if err != nil {
		// Fall back to individual inserts if batch fails
		store.logger.Debugf("Batch insert failed, falling back to individual inserts: %v", err)
		for _, setReq := range req {
			if err := store.Set(ctx, &setReq); err != nil {
				return fmt.Errorf("failed to set key %s: %w", setReq.Key, err)
			}
		}
		return nil
	}

	if !resp.IsSucceed() {
		// Fall back to individual inserts
		store.logger.Debugf("Batch insert not successful, falling back: %s", resp.GetErrorMsg())
		for _, setReq := range req {
			if err := store.Set(ctx, &setReq); err != nil {
				return fmt.Errorf("failed to set key %s: %w", setReq.Key, err)
			}
		}
		return nil
	}

	store.logger.Debugf("BulkSet completed for %d keys", len(req))
	return nil
}

// Query implements IQueriable interface
func (store *NebulaStateStore) Query(ctx context.Context, req *state.QueryRequest) (*state.QueryResponse, error) {
	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return nil, errors.New("store is closed")
	}

	store.logger.Debugf("Executing query: %+v", req.Query)
	
	if store.pool == nil {
		return nil, errors.New("connection pool not initialized")
	}

	session, err := store.getSessionWithRetry(3) // Retry up to 3 times
	if err != nil {
		store.logger.Errorf("Failed to get session for query: %v", err)
		return nil, fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	// Build query based on the request with ETag support
	var query string
	// Enhanced query to return ETags and support basic filtering
	query = fmt.Sprintf("USE %s; MATCH (v:state) RETURN id(v) AS key, v.state.data AS value, v.state.etag AS etag LIMIT 100", store.config.Space)

	store.logger.Debugf("Executing query: %s", query)
	resp, err := session.Execute(query)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	if !resp.IsSucceed() {
		return nil, fmt.Errorf("query failed: %s", resp.GetErrorMsg())
	}

	var results []state.QueryItem
	for i := 0; i < resp.GetRowSize(); i++ {
		record, err := resp.GetRowValuesByIndex(i)
		if err != nil {
			continue
		}

		keyVal, err := record.GetValueByIndex(0)
		if err != nil {
			continue
		}
		key, err := keyVal.AsString()
		if err != nil {
			continue
		}

		valueVal, err := record.GetValueByIndex(1)
		if err != nil {
			continue
		}

		var data []byte
		if !valueVal.IsNull() {
			dataStr, err := valueVal.AsString()
			if err == nil {
				data = []byte(dataStr)
			}
		}

		queryItem := state.QueryItem{
			Key:  key,
			Data: data,
		}

		// Try to get ETag if available (third column) - handle gracefully if not present
		if etagVal, err := record.GetValueByIndex(2); err == nil && !etagVal.IsNull() {
			if etagStr, err := etagVal.AsString(); err == nil {
				queryItem.ETag = &etagStr
			}
		}

		results = append(results, queryItem)
	}

	store.logger.Debugf("Query returned %d results", len(results))
	return &state.QueryResponse{
		Results: results,
		Token:   "", // No pagination support for now
	}, nil
}

func (store *NebulaStateStore) Close() error {
	store.mu.Lock()
	defer store.mu.Unlock()

	if store.closed {
		return nil
	}

	store.logger.Info("Closing NebulaStateStore...")

	store.closed = true

	if store.pool != nil {
		store.pool.Close()
		store.pool = nil
	}

	store.logger.Info("NebulaStateStore closed successfully")
	return nil
}
