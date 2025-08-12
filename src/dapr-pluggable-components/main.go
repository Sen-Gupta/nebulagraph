package main

import (
	"fmt"
	nebulastore "nebulagraph/stores/nebulagraph"
	scyllastore "nebulagraph/stores/scylladb"
	"os"
	"strings"

	dapr "github.com/dapr-sandbox/components-go-sdk"
	"github.com/dapr-sandbox/components-go-sdk/state/v1"
	"github.com/dapr/kit/logger"
)

func main() {
	fmt.Println("DEBUG: Starting Dapr component registration")

	// Get list of stores to register from environment variable
	// Examples:
	// STORE_TYPES="nebulagraph" - single store
	// STORE_TYPES="nebulagraph,scylladb" - multiple stores
	// STORE_TYPES="scylladb,nebulagraph,redis" - future expansion ready
	storeTypes := os.Getenv("STORE_TYPES")
	if storeTypes == "" {
		// Backward compatibility: check old STORE_TYPE variable
		legacyStoreType := os.Getenv("STORE_TYPE")
		switch legacyStoreType {
		case "both":
			storeTypes = "nebulagraph,scylladb"
		case "scylladb":
			storeTypes = "scylladb"
		case "nebulagraph":
			fallthrough
		default:
			storeTypes = "nebulagraph" // default
		}
	}

	// Parse the comma-separated list of store types
	stores := strings.Split(storeTypes, ",")
	registeredStores := make(map[string]bool)

	fmt.Printf("DEBUG: Requested stores: %v\n", stores)

	// Register each requested store
	for _, storeType := range stores {
		storeType = strings.TrimSpace(storeType) // Remove any whitespace

		// Avoid duplicate registrations
		if registeredStores[storeType] {
			fmt.Printf("WARNING: Store type '%s' already registered, skipping duplicate\n", storeType)
			continue
		}

		switch storeType {
		case "nebulagraph":
			fmt.Println("DEBUG: Registering NebulaGraph state store")
			dapr.Register("nebulagraph-state", dapr.WithStateStore(func() state.Store {
				fmt.Println("DEBUG: Factory function called - creating new NebulaStateStore instance")
				store := nebulastore.NewNebulaStateStore(logger.NewLogger("nebulagraph-state"))
				fmt.Printf("DEBUG: Created NebulaGraph store instance: %p\n", store)
				return store
			}))
			registeredStores[storeType] = true

		case "scylladb":
			fmt.Println("DEBUG: Registering ScyllaDB state store")
			dapr.Register("scylladb-state", dapr.WithStateStore(func() state.Store {
				fmt.Println("DEBUG: Factory function called - creating new ScyllaStateStore instance")
				store := scyllastore.NewScyllaStateStore(logger.NewLogger("scylladb-state"))
				fmt.Printf("DEBUG: Created ScyllaDB store instance: %p\n", store)
				return store
			}))
			registeredStores[storeType] = true

		// Future stores can be added here easily
		// case "redis":
		//     fmt.Println("DEBUG: Registering Redis state store")
		//     dapr.Register("redis-state", dapr.WithStateStore(func() state.Store {
		//         store := redisstore.NewRedisStateStore(logger.NewLogger("redis-state"))
		//         return store
		//     }))
		//     registeredStores[storeType] = true

		// case "mongodb":
		//     fmt.Println("DEBUG: Registering MongoDB state store")
		//     dapr.Register("mongodb-state", dapr.WithStateStore(func() state.Store {
		//         store := mongostore.NewMongoStateStore(logger.NewLogger("mongodb-state"))
		//         return store
		//     }))
		//     registeredStores[storeType] = true

		default:
			fmt.Printf("WARNING: Unknown store type '%s', skipping\n", storeType)
		}
	}

	// Verify at least one store was registered
	if len(registeredStores) == 0 {
		fmt.Println("ERROR: No valid stores were registered. Using default NebulaGraph store.")
		dapr.Register("nebulagraph-state", dapr.WithStateStore(func() state.Store {
			store := nebulastore.NewNebulaStateStore(logger.NewLogger("nebulagraph-state"))
			return store
		}))
	}

	fmt.Printf("DEBUG: Successfully registered %d store(s): %v\n", len(registeredStores), getKeys(registeredStores))
	fmt.Println("DEBUG: Registration complete, starting Dapr runtime")
	dapr.MustRun()
}

// Helper function to get keys from map for logging
func getKeys(m map[string]bool) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}
