package main

import (
	"fmt"
	nebulastore "nebulagraph/stores/nebulagraph"
	scyllastore "nebulagraph/stores/scylladb"
	"os"

	dapr "github.com/dapr-sandbox/components-go-sdk"
	"github.com/dapr-sandbox/components-go-sdk/state/v1"
	"github.com/dapr/kit/logger"
)

func main() {
	fmt.Println("DEBUG: Starting Dapr component registration")

	// Check which store type to register based on environment variable
	storeType := os.Getenv("STORE_TYPE")
	if storeType == "" {
		storeType = "nebulagraph" // default
	}

	switch storeType {
	case "scylladb":
		fmt.Println("DEBUG: Registering ScyllaDB state store")
		dapr.Register("scylladb-state", dapr.WithStateStore(func() state.Store {
			fmt.Println("DEBUG: Factory function called - creating new ScyllaStateStore instance")
			store := scyllastore.NewScyllaStateStore(logger.NewLogger("scylladb-state"))
			fmt.Printf("DEBUG: Created ScyllaDB store instance: %p\n", store)
			return store
		}))
	case "nebulagraph":
		fallthrough
	default:
		fmt.Println("DEBUG: Registering NebulaGraph state store")
		dapr.Register("nebulagraph-state", dapr.WithStateStore(func() state.Store {
			fmt.Println("DEBUG: Factory function called - creating new NebulaStateStore instance")
			store := nebulastore.NewNebulaStateStore(logger.NewLogger("nebulagraph-state"))
			fmt.Printf("DEBUG: Created NebulaGraph store instance: %p\n", store)
			return store
		}))
	}

	fmt.Println("DEBUG: Registration complete, starting Dapr runtime")
	dapr.MustRun()
}
