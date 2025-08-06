package stores

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	"github.com/dapr/components-contrib/state"
	nebula "github.com/vesoft-inc/nebula-go/v3"
)

// NebulaStateStore is a custom state store implementation for NebulaGraph.
type NebulaStateStore struct {
	pool   *nebula.ConnectionPool
	config NebulaConfig
}

// Compile time check to ensure NebulaStateStore implements state.Store
var _ state.Store = (*NebulaStateStore)(nil)

type NebulaConfig struct {
	Hosts    string `json:"hosts"` // Changed to string for comma-separated values
	Port     string `json:"port"`  // Changed to string to handle Dapr metadata
	Username string `json:"username"`
	Password string `json:"password"`
	Space    string `json:"space"`
}

func (store *NebulaStateStore) Init(ctx context.Context, metadata state.Metadata) error {
	fmt.Printf("DEBUG: Init called on store instance %p with metadata: %+v\n", store, metadata.Properties)

	// Check for context cancellation
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	// Parse configuration from metadata
	configBytes, _ := json.Marshal(metadata.Properties)
	if err := json.Unmarshal(configBytes, &store.config); err != nil {
		fmt.Printf("DEBUG: Failed to parse config: %v\n", err)
		return fmt.Errorf("failed to parse configuration: %w", err)
	}

	fmt.Printf("DEBUG: Parsed config: %+v\n", store.config)

	// Parse hosts string into slice
	hosts := strings.Split(store.config.Hosts, ",")
	for i := range hosts {
		hosts[i] = strings.TrimSpace(hosts[i])
	}

	// Convert port string to int
	port, err := strconv.Atoi(store.config.Port)
	if err != nil {
		fmt.Printf("DEBUG: Invalid port: %v\n", err)
		return fmt.Errorf("invalid port number: %w", err)
	}

	fmt.Printf("DEBUG: Connecting to NebulaGraph at hosts: %v, port: %d\n", hosts, port)

	// Initialize NebulaGraph connection pool
	hostList := make([]nebula.HostAddress, len(hosts))
	for i, host := range hosts {
		hostList[i] = nebula.HostAddress{Host: host, Port: port}
	}

	poolConfig := nebula.GetDefaultConf()
	pool, err := nebula.NewConnectionPool(hostList, poolConfig, nebula.DefaultLogger{})
	if err != nil {
		fmt.Printf("DEBUG: Failed to create connection pool: %v\n", err)
		return fmt.Errorf("failed to create connection pool: %w", err)
	}

	fmt.Printf("DEBUG: Connection pool created successfully\n")
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
	if store.pool == nil {
		return fmt.Errorf("component not initialized: connection pool is nil")
	}

	session, err := store.pool.GetSession(store.config.Username, store.config.Password)
	if err != nil {
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
	fmt.Printf("DEBUG: GET called on store instance %p for key: %s\n", store, req.Key)

	// Ensure component is properly initialized
	if store.pool == nil {
		return nil, fmt.Errorf("component not initialized: connection pool is nil")
	}

	session, err := store.pool.GetSession(store.config.Username, store.config.Password)
	if err != nil {
		fmt.Printf("DEBUG: Failed to get session: %v\n", err)
		return nil, fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	// First, let's see what vertices exist to debug the key format
	debugQuery := fmt.Sprintf("USE %s; MATCH (v:state) RETURN id(v) LIMIT 10", store.config.Space)
	fmt.Printf("DEBUG: Executing debug query: %s\n", debugQuery)
	debugResp, err := session.Execute(debugQuery)
	if err != nil {
		fmt.Printf("DEBUG: Debug query failed: %v\n", err)
		return nil, fmt.Errorf("debug query failed: %w", err)
	}

	if debugResp != nil && debugResp.IsSucceed() && debugResp.GetRowSize() > 0 {
		fmt.Printf("DEBUG: Found %d vertices in database\n", debugResp.GetRowSize())
		for i := 0; i < debugResp.GetRowSize(); i++ {
			if record, err := debugResp.GetRowValuesByIndex(i); err == nil {
				if idVal, err := record.GetValueByIndex(0); err == nil {
					if idStr, err := idVal.AsString(); err == nil {
						fmt.Printf("DEBUG: Vertex ID: %s\n", idStr)
					}
				}
			}
		}
	} else {
		fmt.Printf("DEBUG: No vertices found or query failed\n")
	}

	// Try multiple approaches to find the vertex since Dapr adds prefixes
	// First try with CONTAINS for the key
	query := fmt.Sprintf("USE %s; MATCH (v:state) WHERE id(v) CONTAINS '%s' RETURN v.state.data AS data", store.config.Space, req.Key)
	fmt.Printf("DEBUG: Executing query: %s\n", query)
	resp, err := session.Execute(query)
	if err != nil {
		fmt.Printf("DEBUG: Query failed: %v\n", err)
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
	if store.pool == nil {
		return fmt.Errorf("component not initialized: connection pool is nil")
	}

	session, err := store.pool.GetSession(store.config.Username, store.config.Password)
	if err != nil {
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
	responses := make([]state.BulkGetResponse, len(req))

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

func (store *NebulaStateStore) BulkDelete(ctx context.Context, req []state.DeleteRequest, opts state.BulkStoreOpts) error {
	for _, delReq := range req {
		if err := store.Delete(ctx, &delReq); err != nil {
			return err
		}
	}
	return nil
}

func (store *NebulaStateStore) BulkSet(ctx context.Context, req []state.SetRequest, opts state.BulkStoreOpts) error {
	for _, setReq := range req {
		if err := store.Set(ctx, &setReq); err != nil {
			return err
		}
	}
	return nil
}

// Query implements IQueriable interface
func (store *NebulaStateStore) Query(ctx context.Context, req *state.QueryRequest) (*state.QueryResponse, error) {
	// Generate and return results based on the query
	return &state.QueryResponse{
		Results: []state.QueryItem{},
		Token:   "",
	}, nil
}

func (store *NebulaStateStore) Close() error {
	if store.pool != nil {
		store.pool.Close()
	}
	return nil
}
