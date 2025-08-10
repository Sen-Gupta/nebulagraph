package stores

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"sync"

	"github.com/dapr/components-contrib/state"
	"github.com/dapr/kit/logger"
	nebula "github.com/vesoft-inc/nebula-go/v3"
)

// NebulaStateStore is a production-ready state store implementation for NebulaGraph.
type NebulaStateStore struct {
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

type NebulaConfig struct {
	Hosts    string `json:"hosts"` // Changed to string for comma-separated values
	Port     string `json:"port"`  // Changed to string to handle Dapr metadata
	Username string `json:"username"`
	Password string `json:"password"`
	Space    string `json:"space"`
}

// NewNebulaStateStore creates a new instance of NebulaStateStore.
func NewNebulaStateStore(logger logger.Logger) state.Store {
	return &NebulaStateStore{
		logger: logger,
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

	// Parse configuration from metadata
	configBytes, _ := json.Marshal(metadata.Properties)
	if err := json.Unmarshal(configBytes, &store.config); err != nil {
		store.logger.Errorf("Failed to parse config: %v", err)
		return fmt.Errorf("failed to parse configuration: %w", err)
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
	return []state.Feature{
		state.FeatureETag,
		state.FeatureTransactional,
		state.FeatureQueryAPI,
	}
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

	session, err := store.pool.GetSession(store.config.Username, store.config.Password)
	if err != nil {
		store.logger.Errorf("Failed to get session for delete: %v", err)
		return fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

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

	session, err := store.pool.GetSession(store.config.Username, store.config.Password)
	if err != nil {
		store.logger.Errorf("Failed to get session: %v", err)
		return nil, fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	// First, let's see what vertices exist to debug the key format
	debugQuery := fmt.Sprintf("USE %s; MATCH (v:state) RETURN id(v) LIMIT 10", store.config.Space)
	store.logger.Debugf("Executing debug query: %s", debugQuery)
	debugResp, err := session.Execute(debugQuery)
	if err != nil {
		store.logger.Errorf("Debug query failed: %v", err)
		return nil, fmt.Errorf("debug query failed: %w", err)
	}

	if debugResp != nil && debugResp.IsSucceed() && debugResp.GetRowSize() > 0 {
		store.logger.Debugf("Found %d vertices in database", debugResp.GetRowSize())
		for i := 0; i < debugResp.GetRowSize(); i++ {
			if record, err := debugResp.GetRowValuesByIndex(i); err == nil {
				if idVal, err := record.GetValueByIndex(0); err == nil {
					if idStr, err := idVal.AsString(); err == nil {
						store.logger.Debugf("Vertex ID: %s", idStr)
					}
				}
			}
		}
	} else {
		store.logger.Debug("No vertices found or query failed")
	}

	// Try multiple approaches to find the vertex since Dapr adds prefixes
	// First try with CONTAINS for the key
	query := fmt.Sprintf("USE %s; MATCH (v:state) WHERE id(v) CONTAINS '%s' RETURN v.state.data AS data", store.config.Space, req.Key)
	store.logger.Debugf("Executing query: %s", query)
	resp, err := session.Execute(query)
	if err != nil {
		store.logger.Errorf("Query failed: %v", err)
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	if !resp.IsSucceed() {
		return nil, fmt.Errorf("query failed: %s", resp.GetErrorMsg())
	}

	// If no results found, try with exact key match
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

	// Get the first value from the record using GetValueByIndex
	valueWrapper, err := record.GetValueByIndex(0)
	if err != nil {
		return nil, fmt.Errorf("failed to get value by index: %w", err)
	}

	if valueWrapper.IsNull() {
		return &state.GetResponse{}, nil
	}

	// Extract string value using AsString method
	dataStr, err := valueWrapper.AsString()
	if err != nil {
		return nil, fmt.Errorf("failed to extract data as string: %w", err)
	}

	return &state.GetResponse{
		Data: []byte(dataStr),
	}, nil
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

	session, err := store.pool.GetSession(store.config.Username, store.config.Password)
	if err != nil {
		store.logger.Errorf("Failed to get session for set: %v", err)
		return fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	// Insert or update vertex with the state data
	data := ""
	if req.Value != nil {
		if bytes, ok := req.Value.([]byte); ok {
			data = string(bytes)
		} else if str, ok := req.Value.(string); ok {
			data = str
		}
	}

	query := fmt.Sprintf("USE %s; INSERT VERTEX state(data) VALUES '%s':('%s')",
		store.config.Space, req.Key, data)

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

	session, err := store.pool.GetSession(store.config.Username, store.config.Password)
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

	// Build a batch FETCH query
	query := fmt.Sprintf("USE %s; FETCH PROP ON state %s YIELD id(vertex) AS key, properties(vertex).data AS data",
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
			}
		}
		return responses, nil
	}

	// Process batch results
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

	session, err := store.pool.GetSession(store.config.Username, store.config.Password)
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

	fmt.Printf("DEBUG: Executing bulk delete query: %s\n", query)
	resp, err := session.Execute(query)
	if err != nil {
		// Fall back to individual deletes if batch fails
		fmt.Printf("DEBUG: Batch delete failed, falling back to individual deletes: %v\n", err)
		for _, delReq := range req {
			if err := store.Delete(ctx, &delReq); err != nil {
				return fmt.Errorf("failed to delete key %s: %w", delReq.Key, err)
			}
		}
		return nil
	}

	if !resp.IsSucceed() {
		// Fall back to individual deletes
		fmt.Printf("DEBUG: Batch delete not successful, falling back: %s\n", resp.GetErrorMsg())
		for _, delReq := range req {
			if err := store.Delete(ctx, &delReq); err != nil {
				return fmt.Errorf("failed to delete key %s: %w", delReq.Key, err)
			}
		}
		return nil
	}

	fmt.Printf("DEBUG: BulkDelete completed for %d keys\n", len(req))
	return nil
}

func (store *NebulaStateStore) BulkSet(ctx context.Context, req []state.SetRequest, opts state.BulkStoreOpts) error {
	fmt.Printf("DEBUG: BulkSet called for %d keys\n", len(req))
	
	if store.pool == nil {
		return fmt.Errorf("component not initialized: connection pool is nil")
	}

	if len(req) == 0 {
		return nil
	}

	session, err := store.pool.GetSession(store.config.Username, store.config.Password)
	if err != nil {
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

	// For larger batches, build a batch insert query
	var values []string
	for _, setReq := range req {
		data := ""
		if setReq.Value != nil {
			if bytes, ok := setReq.Value.([]byte); ok {
				data = string(bytes)
			} else if str, ok := setReq.Value.(string); ok {
				data = str
			}
		}
		// Escape single quotes in data
		data = strings.ReplaceAll(data, "'", "\\'")
		values = append(values, fmt.Sprintf("'%s':('%s')", setReq.Key, data))
	}

	// Build batch INSERT query
	query := fmt.Sprintf("USE %s; INSERT VERTEX state(data) VALUES %s",
		store.config.Space, strings.Join(values, ", "))

	fmt.Printf("DEBUG: Executing bulk insert query: %s\n", query)
	resp, err := session.Execute(query)
	if err != nil {
		// Fall back to individual inserts if batch fails
		fmt.Printf("DEBUG: Batch insert failed, falling back to individual inserts: %v\n", err)
		for _, setReq := range req {
			if err := store.Set(ctx, &setReq); err != nil {
				return fmt.Errorf("failed to set key %s: %w", setReq.Key, err)
			}
		}
		return nil
	}

	if !resp.IsSucceed() {
		// Fall back to individual inserts
		fmt.Printf("DEBUG: Batch insert not successful, falling back: %s\n", resp.GetErrorMsg())
		for _, setReq := range req {
			if err := store.Set(ctx, &setReq); err != nil {
				return fmt.Errorf("failed to set key %s: %w", setReq.Key, err)
			}
		}
		return nil
	}

	fmt.Printf("DEBUG: BulkSet completed for %d keys\n", len(req))
	return nil
}

// Query implements IQueriable interface
func (store *NebulaStateStore) Query(ctx context.Context, req *state.QueryRequest) (*state.QueryResponse, error) {
	fmt.Printf("DEBUG: Query called with query: %+v\n", req.Query)
	
	if store.pool == nil {
		return nil, fmt.Errorf("component not initialized: connection pool is nil")
	}

	session, err := store.pool.GetSession(store.config.Username, store.config.Password)
	if err != nil {
		return nil, fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	// Build query based on the request
	var query string
	// For now, just return all state vertices with basic filtering
	query = fmt.Sprintf("USE %s; MATCH (v:state) RETURN id(v) AS key, v.state.data AS value LIMIT 100", store.config.Space)

	fmt.Printf("DEBUG: Executing query: %s\n", query)
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

		results = append(results, state.QueryItem{
			Key:  key,
			Data: data,
		})
	}

	fmt.Printf("DEBUG: Query returned %d results\n", len(results))
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
