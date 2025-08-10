package main

import (
	"fmt"
	"nebulagraph/stores"

	dapr "github.com/dapr-sandbox/components-go-sdk"
	"github.com/dapr-sandbox/components-go-sdk/state/v1"
	"github.com/dapr/kit/logger"
)

func main() {
	fmt.Println("DEBUG: Starting Dapr component registration")

	dapr.Register("nebulagraph-state", dapr.WithStateStore(func() state.Store {
		fmt.Println("DEBUG: Factory function called - creating new NebulaStateStore instance")
		store := stores.NewNebulaStateStore(logger.NewLogger("nebulagraph-state"))
		fmt.Printf("DEBUG: Created store instance: %p\n", store)
		return store
	}))

	fmt.Println("DEBUG: Registration complete, starting Dapr runtime")
	dapr.MustRun()
}