package main

import (
	"nebulagraph/stores"

	dapr "github.com/dapr-sandbox/components-go-sdk"
	"github.com/dapr-sandbox/components-go-sdk/state/v1"
)

func main() {
	dapr.Register("nebulagraph-state", dapr.WithStateStore(func() state.Store {
		return &stores.NebulaStateStore{}
	}))

	dapr.MustRun()
}
