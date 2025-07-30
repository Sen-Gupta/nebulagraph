package main

import (
	"nebulagraph/components"

	dapr "github.com/dapr-sandbox/components-go-sdk"
	"github.com/dapr-sandbox/components-go-sdk/state/v1"
)

func main() {
	dapr.Register("state.nebulagraph-state", dapr.WithStateStore(func() state.Store {
		return &components.NebulaStateStore{}
	}))

	dapr.MustRun()
}
