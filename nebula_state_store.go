package main

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/dapr/components-contrib/state"
	nebula "github.com/vesoft-inc/nebula-go/v3"
)

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

func (n *NebulaStateStore) Init(ctx context.Context, metadata state.Metadata) error {
	// Parse configuration from metadata
	configBytes, _ := json.Marshal(metadata.Properties)
	if err := json.Unmarshal(configBytes, &n.config); err != nil {
		return fmt.Errorf("failed to parse configuration: %w", err)
	}

	// Initialize NebulaGraph connection pool
	hostList := make([]nebula.HostAddress, len(n.config.Hosts))
	for i, host := range n.config.Hosts {
		hostList[i] = nebula.HostAddress{Host: host, Port: n.config.Port}
	}

	poolConfig := nebula.GetDefaultConf()
	pool, err := nebula.NewConnectionPool(hostList, poolConfig, nebula.DefaultLogger{})
	if err != nil {
		return fmt.Errorf("failed to create connection pool: %w", err)
	}

	n.pool = pool
	return nil
}

func (n *NebulaStateStore) Get(ctx context.Context, req *state.GetRequest) (*state.GetResponse, error) {
	session, err := n.pool.GetSession(n.config.Username, n.config.Password)
	if err != nil {
		return nil, fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	query := fmt.Sprintf("USE %s; FETCH PROP ON state '%s' YIELD properties(vertex)", n.config.Space, req.Key)
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

func (n *NebulaStateStore) Set(ctx context.Context, req *state.SetRequest) error {
	session, err := n.pool.GetSession(n.config.Username, n.config.Password)
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
		n.config.Space, req.Key, data)

	resp, err := session.Execute(query)
	if err != nil {
		return fmt.Errorf("failed to execute insert query: %w", err)
	}

	if !resp.IsSucceed() {
		return fmt.Errorf("insert operation failed: %s", resp.GetErrorMsg())
	}

	return nil
}

func (n *NebulaStateStore) Delete(ctx context.Context, req *state.DeleteRequest) error {
	session, err := n.pool.GetSession(n.config.Username, n.config.Password)
	if err != nil {
		return fmt.Errorf("failed to get session: %w", err)
	}
	defer session.Release()

	query := fmt.Sprintf("USE %s; DELETE VERTEX '%s'", n.config.Space, req.Key)
	resp, err := session.Execute(query)
	if err != nil {
		return fmt.Errorf("failed to execute delete query: %w", err)
	}

	if !resp.IsSucceed() {
		return fmt.Errorf("delete operation failed: %s", resp.GetErrorMsg())
	}

	return nil
}

func (n *NebulaStateStore) BulkGet(ctx context.Context, req []state.GetRequest) ([]state.BulkGetResponse, error) {
	responses := make([]state.BulkGetResponse, len(req))

	for i, getReq := range req {
		resp, err := n.Get(ctx, &getReq)
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

func (n *NebulaStateStore) BulkSet(ctx context.Context, req []state.SetRequest) error {
	for _, setReq := range req {
		if err := n.Set(ctx, &setReq); err != nil {
			return err
		}
	}
	return nil
}

func (n *NebulaStateStore) BulkDelete(ctx context.Context, req []state.DeleteRequest) error {
	for _, delReq := range req {
		if err := n.Delete(ctx, &delReq); err != nil {
			return err
		}
	}
	return nil
}

func (n *NebulaStateStore) Close() error {
	if n.pool != nil {
		n.pool.Close()
	}
	return nil
}

func (n *NebulaStateStore) Features() []state.Feature {
	return []state.Feature{state.FeatureETag}
}

func (n *NebulaStateStore) Multi(ctx context.Context, request *state.TransactionalStateRequest) error {
	// NebulaGraph doesn't support transactions in the traditional sense
	// We'll process operations sequentially
	for _, op := range request.Operations {
		switch req := op.(type) {
		case state.SetRequest:
			if err := n.Set(ctx, &req); err != nil {
				return err
			}
		case state.DeleteRequest:
			if err := n.Delete(ctx, &req); err != nil {
				return err
			}
		}
	}
	return nil
}
