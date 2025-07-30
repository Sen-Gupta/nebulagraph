package components

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/dapr/components-contrib/state"
	nebula "github.com/vesoft-inc/nebula-go/v3"
)

// NebulaStateStore is a custom state store implementation for NebulaGraph.
type NebulaStateStore struct {
	pool   *nebula.ConnectionPool
	config NebulaConfig
}

type NebulaConfig struct {
	Hosts    []string `json:"hosts"`
	Port     int      `json:"port"`
	Username string   `json:"username"`
	Password string   `json:"password"`
	Space    string   `json:"space"`
}

func (store *NebulaStateStore) Init(ctx context.Context, metadata state.Metadata) error {
	// Parse configuration from metadata
	configBytes, _ := json.Marshal(metadata.Properties)
	if err := json.Unmarshal(configBytes, &store.config); err != nil {
		return fmt.Errorf("failed to parse configuration: %w", err)
	}

	// Initialize NebulaGraph connection pool
	hostList := make([]nebula.HostAddress, len(store.config.Hosts))
	for i, host := range store.config.Hosts {
		hostList[i] = nebula.HostAddress{Host: host, Port: store.config.Port}
	}

	poolConfig := nebula.GetDefaultConf()
	pool, err := nebula.NewConnectionPool(hostList, poolConfig, nebula.DefaultLogger{})
	if err != nil {
		return fmt.Errorf("failed to create connection pool: %w", err)
	}

	store.pool = pool
	return nil
}

func (store *NebulaStateStore) GetComponentMetadata() map[string]string {
	// Not used with pluggable components...
	return map[string]string{}
}

func (store *NebulaStateStore) Features() []state.Feature {
	// Return a list of features supported by the state store...
	return []state.Feature{state.FeatureETag}
}

func (store *NebulaStateStore) Delete(ctx context.Context, req *state.DeleteRequest) error {
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
	session, err := store.pool.GetSession(store.config.Username, store.config.Password)
	if err != nil {
		return nil, fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	query := fmt.Sprintf("USE %s; FETCH PROP ON state '%s' YIELD properties(vertex)", store.config.Space, req.Key)
	resp, err := session.Execute(query)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}

	if !resp.IsSucceed() || resp.GetRowSize() == 0 {
		return &state.GetResponse{}, nil
	}

	// For now, return empty response - this would need proper implementation
	// based on the exact nebula-go API version you're using
	return &state.GetResponse{}, nil
}

func (store *NebulaStateStore) Set(ctx context.Context, req *state.SetRequest) error {
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
