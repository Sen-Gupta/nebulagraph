package components
package components

import (
	"context"
	"github.com/dapr/components-contrib/state"
)
// NebulaStateStore is a custom state store implementation for NebulaGraph.
type NebulaStateStore struct {
}

func (store *NebulaStateStore) Init(metadata state.Metadata) error {
	// Called to initialize the component with its configured metadata...
}

func (store *NebulaStateStore) GetComponentMetadata() map[string]string {
    // Not used with pluggable components...
	return map[string]string{}
}

func (store *NebulaStateStore) Features() []state.Feature {
	// Return a list of features supported by the state store...
}

func (store *NebulaStateStore) Delete(ctx context.Context, req *state.DeleteRequest) error {
	// Delete the requested key from the state store...
}

func (store *NebulaStateStore) Get(ctx context.Context, req *state.GetRequest) (*state.GetResponse, error) {
	// Get the requested key value from the state store, else return an empty response...
}

func (store *NebulaStateStore) Set(ctx context.Context, req *state.SetRequest) error {
	// Set the requested key to the specified value in the state store...
}

func (store *NebulaStateStore) BulkGet(ctx context.Context, req []state.GetRequest) (bool, []state.BulkGetResponse, error) {
	// Get the requested key values from the state store...
}

func (store *NebulaStateStore) BulkDelete(ctx context.Context, req []state.DeleteRequest) error {
	// Delete the requested keys from the state store...
}

func (store *NebulaStateStore) BulkSet(ctx context.Context, req []state.SetRequest) error {
	// Set the requested keys to their specified values in the state store...
}

//IQueriable
func (store *MyStateStoreComponent) Query(ctx context.Context, req *state.QueryRequest) (*state.QueryResponse, error) {
	// Generate and return results...
}

