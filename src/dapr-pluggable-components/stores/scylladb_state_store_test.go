package stores

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/dapr/components-contrib/state"
	"github.com/dapr/kit/logger"
)

func TestScyllaStateStore_Basic(t *testing.T) {
	// Skip if no ScyllaDB instance is available
	if testing.Short() {
		t.Skip("Skipping ScyllaDB integration test in short mode")
	}

	store := NewScyllaStateStore(logger.NewLogger("test"))
	
	// Test metadata configuration
	metadata := state.Metadata{
		Properties: map[string]string{
			"hosts":     "localhost",
			"port":      "9042",
			"username":  os.Getenv("SCYLLA_USERNAME"),
			"password":  os.Getenv("SCYLLA_PASSWORD"),
			"keyspace":  "test_keyspace",
			"table":     "test_state",
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Note: This test requires a running ScyllaDB instance
	// In a real test environment, you would set up a test ScyllaDB container
	err := store.Init(ctx, metadata)
	if err != nil {
		t.Logf("ScyllaDB not available, skipping test: %v", err)
		return
	}
	defer store.Close()

	// Test basic set/get operations
	testKey := "test-key"
	testValue := "test-value"

	// Set a value
	setReq := &state.SetRequest{
		Key:   testKey,
		Value: testValue,
	}
	
	err = store.Set(ctx, setReq)
	if err != nil {
		t.Fatalf("Failed to set value: %v", err)
	}

	// Get the value
	getReq := &state.GetRequest{
		Key: testKey,
	}
	
	getResp, err := store.Get(ctx, getReq)
	if err != nil {
		t.Fatalf("Failed to get value: %v", err)
	}

	if string(getResp.Data) != testValue {
		t.Errorf("Expected %s, got %s", testValue, string(getResp.Data))
	}

	// Test delete
	delReq := &state.DeleteRequest{
		Key: testKey,
	}
	
	err = store.Delete(ctx, delReq)
	if err != nil {
		t.Fatalf("Failed to delete value: %v", err)
	}

	// Verify deletion
	getResp, err = store.Get(ctx, getReq)
	if err != nil {
		t.Fatalf("Failed to get value after deletion: %v", err)
	}

	if len(getResp.Data) != 0 {
		t.Errorf("Expected empty data after deletion, got %s", string(getResp.Data))
	}
}

func TestScyllaStateStore_Query(t *testing.T) {
	// Skip if no ScyllaDB instance is available
	if testing.Short() {
		t.Skip("Skipping ScyllaDB integration test in short mode")
	}

	store := NewScyllaStateStore(logger.NewLogger("test"))
	
	metadata := state.Metadata{
		Properties: map[string]string{
			"hosts":     "localhost",
			"port":      "9042",
			"username":  os.Getenv("SCYLLA_USERNAME"),
			"password":  os.Getenv("SCYLLA_PASSWORD"),
			"keyspace":  "test_keyspace",
			"table":     "test_state",
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	err := store.Init(ctx, metadata)
	if err != nil {
		t.Logf("ScyllaDB not available, skipping test: %v", err)
		return
	}
	defer store.Close()

	// Test query interface for DDL
	queryReq := &state.QueryRequest{
		Query: map[string]interface{}{
			"query": "CREATE TABLE IF NOT EXISTS test_table (id text PRIMARY KEY, data text)",
		},
	}

	queryResp, err := store.Query(ctx, queryReq)
	if err != nil {
		t.Fatalf("Failed to execute DDL query: %v", err)
	}

	if len(queryResp.Results) == 0 {
		t.Error("Expected query response results")
	}

	t.Logf("Query executed successfully: %+v", queryResp.Results[0])
}
