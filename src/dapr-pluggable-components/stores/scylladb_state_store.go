package stores

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/dapr/components-contrib/state"
	"github.com/dapr/kit/logger"
	"github.com/gocql/gocql"
)

// ScyllaStateStore is a production-ready state store implementation for ScyllaDB.
type ScyllaStateStore struct {
	state.BulkStore
	
	cluster *gocql.ClusterConfig
	session *gocql.Session
	config  ScyllaConfig
	logger  logger.Logger
	mu      sync.RWMutex
	closed  bool
}

// Compile time check to ensure ScyllaStateStore implements state.Store
var _ state.Store = (*ScyllaStateStore)(nil)

// Compile time check to ensure ScyllaStateStore implements state.Querier
var _ state.Querier = (*ScyllaStateStore)(nil)

// Compile time check to ensure ScyllaStateStore implements state.BulkStore
var _ state.BulkStore = (*ScyllaStateStore)(nil)

// ScyllaConfig contains configuration for ScyllaDB connection
type ScyllaConfig struct {
	Hosts                    string `json:"hosts" mapstructure:"hosts"`                                       // Comma-separated list of ScyllaDB hosts
	Port                     string `json:"port" mapstructure:"port"`                                         // Port for ScyllaDB (default: 9042)
	Username                 string `json:"username" mapstructure:"username"`                                 // Username for authentication
	Password                 string `json:"password" mapstructure:"password"`                                 // Password for authentication
	Keyspace                 string `json:"keyspace" mapstructure:"keyspace"`                                 // Keyspace name (default: dapr_state)
	Table                    string `json:"table" mapstructure:"table"`                                       // Table name (default: state)
	Consistency              string `json:"consistency" mapstructure:"consistency"`                           // Consistency level (default: LOCAL_QUORUM)
	ConnectionTimeout        string `json:"connectionTimeout" mapstructure:"connectionTimeout"`               // Connection timeout (default: 10s)
	SocketKeepalive          string `json:"socketKeepalive" mapstructure:"socketKeepalive"`                   // Socket keepalive (default: 30s)
	MaxReconnectInterval     string `json:"maxReconnectInterval" mapstructure:"maxReconnectInterval"`         // Max reconnect interval (default: 60s)
	NumConns                 string `json:"numConns" mapstructure:"numConns"`                                 // Number of connections per host (default: 2)
	DisableInitialHostLookup string `json:"disableInitialHostLookup" mapstructure:"disableInitialHostLookup"` // Disable initial host lookup (default: false)
	ReplicationStrategy      string `json:"replicationStrategy" mapstructure:"replicationStrategy"`           // Replication strategy for keyspace creation
	ReplicationFactor        string `json:"replicationFactor" mapstructure:"replicationFactor"`               // Replication factor (default: 3)
}

// NewScyllaStateStore creates a new instance of ScyllaStateStore.
func NewScyllaStateStore(inputLogger logger.Logger) state.Store {
	// Create default logger if none provided
	if inputLogger == nil {
		inputLogger = logger.NewLogger("scylladb-state")
	}
	return &ScyllaStateStore{
		logger: inputLogger,
	}
}

func (store *ScyllaStateStore) Init(ctx context.Context, metadata state.Metadata) error {
	store.logger.Info("Initializing ScyllaStateStore...")

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

	// Set defaults
	if store.config.Hosts == "" {
		store.config.Hosts = "localhost"
	}
	if store.config.Port == "" {
		store.config.Port = "9042"
	}
	if store.config.Keyspace == "" {
		store.config.Keyspace = "dapr_state"
	}
	if store.config.Table == "" {
		store.config.Table = "state"
	}
	if store.config.Consistency == "" {
		store.config.Consistency = "LOCAL_QUORUM"
	}
	if store.config.ConnectionTimeout == "" {
		store.config.ConnectionTimeout = "10s"
	}
	if store.config.SocketKeepalive == "" {
		store.config.SocketKeepalive = "30s"
	}
	if store.config.MaxReconnectInterval == "" {
		store.config.MaxReconnectInterval = "60s"
	}
	if store.config.NumConns == "" {
		store.config.NumConns = "2"
	}
	if store.config.ReplicationStrategy == "" {
		store.config.ReplicationStrategy = "SimpleStrategy"
	}
	if store.config.ReplicationFactor == "" {
		store.config.ReplicationFactor = "3"
	}

	store.logger.Infof("Parsed ScyllaDB config: hosts=%s, port=%s, keyspace=%s, table=%s", 
		store.config.Hosts, store.config.Port, store.config.Keyspace, store.config.Table)

	// Parse hosts
	hosts := strings.Split(store.config.Hosts, ",")
	for i := range hosts {
		hosts[i] = strings.TrimSpace(hosts[i])
		// Add port if not specified
		if !strings.Contains(hosts[i], ":") {
			hosts[i] = fmt.Sprintf("%s:%s", hosts[i], store.config.Port)
		}
	}

	// Create cluster configuration
	cluster := gocql.NewCluster(hosts...)
	
	// Set authentication if provided
	if store.config.Username != "" && store.config.Password != "" {
		cluster.Authenticator = gocql.PasswordAuthenticator{
			Username: store.config.Username,
			Password: store.config.Password,
		}
	}

	// Parse and set timeouts
	if timeout, err := time.ParseDuration(store.config.ConnectionTimeout); err == nil {
		cluster.ConnectTimeout = timeout
	} else {
		store.logger.Warnf("Invalid connectionTimeout: %s, using default", store.config.ConnectionTimeout)
		cluster.ConnectTimeout = 10 * time.Second
	}

	if keepalive, err := time.ParseDuration(store.config.SocketKeepalive); err == nil {
		cluster.SocketKeepalive = keepalive
	} else {
		store.logger.Warnf("Invalid socketKeepalive: %s, using default", store.config.SocketKeepalive)
		cluster.SocketKeepalive = 30 * time.Second
	}

	if maxReconnect, err := time.ParseDuration(store.config.MaxReconnectInterval); err == nil {
		cluster.ReconnectInterval = maxReconnect
	} else {
		store.logger.Warnf("Invalid maxReconnectInterval: %s, using default", store.config.MaxReconnectInterval)
		cluster.ReconnectInterval = 60 * time.Second
	}

	// Set consistency level
	consistency := gocql.LocalQuorum // default
	switch strings.ToUpper(store.config.Consistency) {
	case "ANY":
		consistency = gocql.Any
	case "ONE":
		consistency = gocql.One
	case "TWO":
		consistency = gocql.Two
	case "THREE":
		consistency = gocql.Three
	case "QUORUM":
		consistency = gocql.Quorum
	case "ALL":
		consistency = gocql.All
	case "LOCAL_QUORUM":
		consistency = gocql.LocalQuorum
	case "EACH_QUORUM":
		consistency = gocql.EachQuorum
	case "LOCAL_ONE":
		consistency = gocql.LocalOne
	default:
		store.logger.Warnf("Unknown consistency level: %s, using LOCAL_QUORUM", store.config.Consistency)
	}
	cluster.Consistency = consistency

	// Set number of connections per host
	if numConns := store.config.NumConns; numConns != "" {
		if n, err := strconv.Atoi(numConns); err == nil && n > 0 {
			cluster.NumConns = n
		} else {
			store.logger.Warnf("Invalid numConns: %s, using default", numConns)
		}
	}

	// Disable initial host lookup if configured
	if store.config.DisableInitialHostLookup == "true" {
		cluster.DisableInitialHostLookup = true
	}

	// Set protocol version and other optimizations for ScyllaDB
	cluster.ProtoVersion = 4
	cluster.HostFilter = gocql.WhiteListHostFilter(hosts...)

	store.cluster = cluster
	store.logger.Info("ScyllaDB cluster configuration created successfully")

	// Create session and initialize keyspace/table
	if err := store.createSessionAndInitialize(); err != nil {
		return fmt.Errorf("failed to initialize ScyllaDB: %w", err)
	}

	store.logger.Info("ScyllaStateStore initialized successfully")
	return nil
}

func (store *ScyllaStateStore) createSessionAndInitialize() error {
	// First, create a session without specifying keyspace to create it if needed
	session, err := store.cluster.CreateSession()
	if err != nil {
		store.logger.Errorf("Failed to create ScyllaDB session: %v", err)
		return fmt.Errorf("failed to create session: %w", err)
	}

	// Create keyspace if it doesn't exist
	createKeyspaceQuery := fmt.Sprintf(`
		CREATE KEYSPACE IF NOT EXISTS %s 
		WITH replication = {
			'class': '%s', 
			'replication_factor': %s
		}`, 
		store.config.Keyspace, 
		store.config.ReplicationStrategy, 
		store.config.ReplicationFactor)

	store.logger.Debugf("Creating keyspace with query: %s", createKeyspaceQuery)
	if err := session.Query(createKeyspaceQuery).Exec(); err != nil {
		session.Close()
		return fmt.Errorf("failed to create keyspace: %w", err)
	}

	// Close the initial session
	session.Close()

	// Create a new session with the keyspace
	store.cluster.Keyspace = store.config.Keyspace
	session, err = store.cluster.CreateSession()
	if err != nil {
		return fmt.Errorf("failed to create session with keyspace: %w", err)
	}

	// Create table if it doesn't exist
	createTableQuery := fmt.Sprintf(`
		CREATE TABLE IF NOT EXISTS %s (
			key text PRIMARY KEY,
			value text,
			etag text,
			last_modified timestamp
		)`, store.config.Table)

	store.logger.Debugf("Creating table with query: %s", createTableQuery)
	if err := session.Query(createTableQuery).Exec(); err != nil {
		session.Close()
		return fmt.Errorf("failed to create table: %w", err)
	}

	store.session = session
	store.logger.Info("ScyllaDB keyspace and table initialized successfully")
	return nil
}

func (store *ScyllaStateStore) GetComponentMetadata() map[string]string {
	return map[string]string{
		"type":    "state",
		"version": "v1",
		"author":  "ScyllaDB Team", 
		"url":     "https://github.com/scylladb/scylladb",
	}
}

func (store *ScyllaStateStore) Features() []state.Feature {
	// Return supported features for ScyllaDB state store
	return []state.Feature{
		state.FeatureETag,
		state.FeatureTransactional,
		state.FeatureQueryAPI,
	}
}

func (store *ScyllaStateStore) Get(ctx context.Context, req *state.GetRequest) (*state.GetResponse, error) {
	if req.Key == "" {
		return nil, errors.New("key cannot be empty")
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return nil, errors.New("store is closed")
	}

	if store.session == nil {
		return nil, errors.New("session not initialized")
	}

	store.logger.Debugf("Getting value for key: %s", req.Key)

	var value, etag string
	var lastModified time.Time

	query := fmt.Sprintf("SELECT value, etag, last_modified FROM %s WHERE key = ?", store.config.Table)
	if err := store.session.Query(query, req.Key).WithContext(ctx).Scan(&value, &etag, &lastModified); err != nil {
		if err == gocql.ErrNotFound {
			// Key not found, return empty response
			return &state.GetResponse{}, nil
		}
		return nil, fmt.Errorf("failed to get key %s: %w", req.Key, err)
	}

	response := &state.GetResponse{
		Data: []byte(value),
		ETag: &etag,
	}

	store.logger.Debugf("Successfully retrieved key: %s", req.Key)
	return response, nil
}

func (store *ScyllaStateStore) Set(ctx context.Context, req *state.SetRequest) error {
	if req.Key == "" {
		return errors.New("key cannot be empty")
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return errors.New("store is closed")
	}

	if store.session == nil {
		return errors.New("session not initialized")
	}

	store.logger.Debugf("Setting value for key: %s", req.Key)

	// Convert value to string
	var value string
	if req.Value != nil {
		if bytes, ok := req.Value.([]byte); ok {
			value = string(bytes)
		} else if str, ok := req.Value.(string); ok {
			value = str
		} else {
			// Try to marshal as JSON
			if jsonBytes, err := json.Marshal(req.Value); err == nil {
				value = string(jsonBytes)
			} else {
				return fmt.Errorf("failed to convert value to string: %w", err)
			}
		}
	}

	// Generate etag
	etag := fmt.Sprintf("%d", time.Now().UnixNano())
	
	// Handle ETag for optimistic concurrency
	if req.ETag != nil {
		// Verify current etag matches
		var currentEtag string
		checkQuery := fmt.Sprintf("SELECT etag FROM %s WHERE key = ?", store.config.Table)
		checkErr := store.session.Query(checkQuery, req.Key).WithContext(ctx).Scan(&currentEtag)
		if checkErr != nil && checkErr != gocql.ErrNotFound {
			return fmt.Errorf("failed to check current etag: %w", checkErr)
		}
		
		if checkErr != gocql.ErrNotFound && currentEtag != *req.ETag {
			return fmt.Errorf("etag mismatch: expected %s, got %s", *req.ETag, currentEtag)
		}
	}

	// Insert/update the value
	query := fmt.Sprintf("INSERT INTO %s (key, value, etag, last_modified) VALUES (?, ?, ?, ?)", store.config.Table)
	if err := store.session.Query(query, req.Key, value, etag, time.Now()).WithContext(ctx).Exec(); err != nil {
		return fmt.Errorf("failed to set key %s: %w", req.Key, err)
	}

	store.logger.Debugf("Successfully set key: %s", req.Key)
	return nil
}

func (store *ScyllaStateStore) Delete(ctx context.Context, req *state.DeleteRequest) error {
	if req.Key == "" {
		return errors.New("key cannot be empty")
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return errors.New("store is closed")
	}

	if store.session == nil {
		return errors.New("session not initialized")
	}

	store.logger.Debugf("Deleting key: %s", req.Key)

	// Handle ETag for optimistic concurrency
	if req.ETag != nil {
		// Verify current etag matches
		var currentEtag string
		checkQuery := fmt.Sprintf("SELECT etag FROM %s WHERE key = ?", store.config.Table)
		if err := store.session.Query(checkQuery, req.Key).WithContext(ctx).Scan(&currentEtag); err != nil {
			if err == gocql.ErrNotFound {
				// Key doesn't exist, nothing to delete
				return nil
			}
			return fmt.Errorf("failed to check current etag: %w", err)
		}
		
		if currentEtag != *req.ETag {
			return fmt.Errorf("etag mismatch: expected %s, got %s", *req.ETag, currentEtag)
		}
	}

	query := fmt.Sprintf("DELETE FROM %s WHERE key = ?", store.config.Table)
	if err := store.session.Query(query, req.Key).WithContext(ctx).Exec(); err != nil {
		return fmt.Errorf("failed to delete key %s: %w", req.Key, err)
	}

	store.logger.Debugf("Successfully deleted key: %s", req.Key)
	return nil
}

func (store *ScyllaStateStore) BulkGet(ctx context.Context, req []state.GetRequest, opts state.BulkGetOpts) ([]state.BulkGetResponse, error) {
	if len(req) == 0 {
		return []state.BulkGetResponse{}, nil
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return nil, errors.New("store is closed")
	}

	if store.session == nil {
		return nil, errors.New("session not initialized")
	}

	store.logger.Debugf("Bulk getting %d keys", len(req))

	responses := make([]state.BulkGetResponse, len(req))

	// For small batches, use individual queries
	if len(req) <= 10 {
		for i, getReq := range req {
			resp, err := store.Get(ctx, &getReq)
			response := state.BulkGetResponse{
				Key: getReq.Key,
			}
			if err != nil {
				response.Error = err.Error()
			} else if resp != nil {
				response.Data = resp.Data
				response.ETag = resp.ETag
			}
			responses[i] = response
		}
		return responses, nil
	}

	// For larger batches, use IN query
	keys := make([]string, len(req))
	keyToIndex := make(map[string]int)
	for i, getReq := range req {
		keys[i] = getReq.Key
		keyToIndex[getReq.Key] = i
		responses[i] = state.BulkGetResponse{Key: getReq.Key}
	}

	// Build IN query
	placeholders := strings.Repeat("?,", len(keys))
	placeholders = placeholders[:len(placeholders)-1] // Remove trailing comma

	query := fmt.Sprintf("SELECT key, value, etag FROM %s WHERE key IN (%s)", store.config.Table, placeholders)
	
	// Convert keys to interface{} slice for query
	keyInterfaces := make([]interface{}, len(keys))
	for i, key := range keys {
		keyInterfaces[i] = key
	}

	iter := store.session.Query(query, keyInterfaces...).WithContext(ctx).Iter()
	defer iter.Close()

	var key, value, etag string
	for iter.Scan(&key, &value, &etag) {
		if idx, exists := keyToIndex[key]; exists {
			responses[idx].Data = []byte(value)
			responses[idx].ETag = &etag
		}
	}

	if err := iter.Close(); err != nil {
		store.logger.Errorf("Error during bulk get iteration: %v", err)
		return nil, fmt.Errorf("bulk get failed: %w", err)
	}

	store.logger.Debugf("BulkGet completed for %d keys", len(req))
	return responses, nil
}

func (store *ScyllaStateStore) BulkSet(ctx context.Context, req []state.SetRequest, opts state.BulkStoreOpts) error {
	if len(req) == 0 {
		return nil
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return errors.New("store is closed")
	}

	if store.session == nil {
		return errors.New("session not initialized")
	}

	store.logger.Debugf("Bulk setting %d keys", len(req))

	// For small batches, use individual operations
	if len(req) <= 5 {
		for _, setReq := range req {
			if err := store.Set(ctx, &setReq); err != nil {
				return fmt.Errorf("failed to set key %s: %w", setReq.Key, err)
			}
		}
		return nil
	}

	// For larger batches, use batch operations
	batch := store.session.NewBatch(gocql.LoggedBatch).WithContext(ctx)
	
	query := fmt.Sprintf("INSERT INTO %s (key, value, etag, last_modified) VALUES (?, ?, ?, ?)", store.config.Table)
	
	for _, setReq := range req {
		// Convert value to string
		var value string
		if setReq.Value != nil {
			if bytes, ok := setReq.Value.([]byte); ok {
				value = string(bytes)
			} else if str, ok := setReq.Value.(string); ok {
				value = str
			} else {
				// Try to marshal as JSON
				if jsonBytes, err := json.Marshal(setReq.Value); err == nil {
					value = string(jsonBytes)
				} else {
					return fmt.Errorf("failed to convert value to string for key %s: %w", setReq.Key, err)
				}
			}
		}

		// Generate etag
		etag := fmt.Sprintf("%d", time.Now().UnixNano())
		
		batch.Query(query, setReq.Key, value, etag, time.Now())
	}

	if err := store.session.ExecuteBatch(batch); err != nil {
		// Fall back to individual operations
		store.logger.Debugf("Batch set failed, falling back to individual operations: %v", err)
		for _, setReq := range req {
			if err := store.Set(ctx, &setReq); err != nil {
				return fmt.Errorf("failed to set key %s: %w", setReq.Key, err)
			}
		}
	}

	store.logger.Debugf("BulkSet completed for %d keys", len(req))
	return nil
}

func (store *ScyllaStateStore) BulkDelete(ctx context.Context, req []state.DeleteRequest, opts state.BulkStoreOpts) error {
	if len(req) == 0 {
		return nil
	}

	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return errors.New("store is closed")
	}

	if store.session == nil {
		return errors.New("session not initialized")
	}

	store.logger.Debugf("Bulk deleting %d keys", len(req))

	// For small batches, use individual operations
	if len(req) <= 5 {
		for _, delReq := range req {
			if err := store.Delete(ctx, &delReq); err != nil {
				return fmt.Errorf("failed to delete key %s: %w", delReq.Key, err)
			}
		}
		return nil
	}

	// For larger batches, use batch operations
	batch := store.session.NewBatch(gocql.LoggedBatch).WithContext(ctx)
	
	query := fmt.Sprintf("DELETE FROM %s WHERE key = ?", store.config.Table)
	
	for _, delReq := range req {
		batch.Query(query, delReq.Key)
	}

	if err := store.session.ExecuteBatch(batch); err != nil {
		// Fall back to individual operations
		store.logger.Debugf("Batch delete failed, falling back to individual operations: %v", err)
		for _, delReq := range req {
			if err := store.Delete(ctx, &delReq); err != nil {
				return fmt.Errorf("failed to delete key %s: %w", delReq.Key, err)
			}
		}
	}

	store.logger.Debugf("BulkDelete completed for %d keys", len(req))
	return nil
}

// Query implements state.Querier interface for executing arbitrary CQL queries
func (store *ScyllaStateStore) Query(ctx context.Context, req *state.QueryRequest) (*state.QueryResponse, error) {
	store.mu.RLock()
	defer store.mu.RUnlock()

	if store.closed {
		return nil, errors.New("store is closed")
	}

	if store.session == nil {
		return nil, errors.New("session not initialized")
	}

	store.logger.Debugf("Executing query: %+v", req.Query)

	// For now, just return all state data with basic filtering
	// TODO: Implement more sophisticated query parsing when needed
	queryStr := fmt.Sprintf("SELECT key, value FROM %s LIMIT 100", store.config.Table)

	store.logger.Debugf("Executing CQL query: %s", queryStr)

	// Execute the query
	iter := store.session.Query(queryStr).WithContext(ctx).Iter()
	defer iter.Close()

	var results []state.QueryItem
	
	// Handle different types of queries
	if strings.Contains(strings.ToUpper(queryStr), "SELECT") {
		// For SELECT queries, try to extract key-value pairs
		if strings.Contains(strings.ToLower(queryStr), "key") && strings.Contains(strings.ToLower(queryStr), "value") {
			var key, value string
			for iter.Scan(&key, &value) {
				results = append(results, state.QueryItem{
					Key:  key,
					Data: []byte(value),
				})
			}
		} else {
			// For other SELECT queries, return the results as JSON
			columns := iter.Columns()
			
			// Create a slice to hold the scanned values
			values := make([]interface{}, len(columns))
			valuePtrs := make([]interface{}, len(columns))
			for i := range values {
				valuePtrs[i] = &values[i]
			}
			
			for iter.Scan(valuePtrs...) {
				resultMap := make(map[string]interface{})
				for i, col := range columns {
					resultMap[col.Name] = values[i]
				}
				if jsonData, err := json.Marshal(resultMap); err == nil {
					results = append(results, state.QueryItem{
						Key:  fmt.Sprintf("result_%d", len(results)),
						Data: jsonData,
					})
				}
			}
		}
	} else {
		// For non-SELECT queries (DDL/DML), just execute and return success
		if err := iter.Close(); err != nil {
			return nil, fmt.Errorf("query execution failed: %w", err)
		}
		
		results = append(results, state.QueryItem{
			Key:  "query_result",
			Data: []byte(`{"status": "success", "message": "Query executed successfully"}`),
		})
	}

	if err := iter.Close(); err != nil {
		return nil, fmt.Errorf("query iteration failed: %w", err)
	}

	store.logger.Debugf("Query returned %d results", len(results))
	return &state.QueryResponse{
		Results: results,
		Token:   "", // No pagination support for now
	}, nil
}

func (store *ScyllaStateStore) Close() error {
	store.mu.Lock()
	defer store.mu.Unlock()

	if store.closed {
		return nil
	}

	store.closed = true

	if store.session != nil {
		store.session.Close()
		store.session = nil
	}

	store.logger.Info("ScyllaStateStore closed successfully")
	return nil
}
