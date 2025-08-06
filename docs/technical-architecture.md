# NebulaGraph Dapr Pluggable Component - Technical Architecture

## Architecture Overview

The NebulaGraph Dapr Pluggable Component follows Dapr's official pluggable component architecture, providing a state store implementation that integrates NebulaGraph as the backend storage system.

## Core Components

### 1. Component Structure

```
src/dapr-pluggable/
├── main.go                    # Entry point & Dapr registration
├── Dockerfile                 # Production container image
├── Dockerfile.test           # Testing container image
├── stores/
│   └── nebulagraph_store.go  # State store implementation
├── tests/
│   ├── test_all.sh           # Complete test suite
│   ├── test_component.sh     # HTTP API tests
│   └── test_component_grpc.sh # gRPC API tests
└── setup/
    └── docker/
        └── docker-compose.yml # Multi-container orchestration
```

### 2. Communication Architecture

```mermaid
graph LR
    subgraph "Communication Layer"
        A[HTTP Client] --> B[Dapr HTTP API :3501]
        C[gRPC Client] --> D[Dapr gRPC API :50001]
        
        B --> E[Dapr Runtime]
        D --> E
        
        E <--> F[Unix Domain Socket<br/>/var/run]
        F <--> G[NebulaGraph Component<br/>gRPC Server]
        
        G --> H[NebulaGraph Client]
        H --> I[NebulaGraph Database<br/>:9669]
    end
    
    style F fill:#f1f8e9
    style E fill:#f3e5f5
    style G fill:#e8f5e8
    style I fill:#fce4ec
```

## Implementation Details

### 3. Registration Pattern

```go
// main.go - Dapr component registration
func main() {
    dapr.Register("nebulagraph-state", dapr.WithStateStore(func() state.Store {
        return &stores.NebulaStateStore{}
    }))
    dapr.MustRun()
}
```

### 4. Interface Implementation

```mermaid
classDiagram
    direction TB
    
    class StateStore {
        <<interface>>
        +Init(context.Context, state.Metadata) error
        +Get(context.Context, *state.GetRequest) (*state.GetResponse, error)
        +Set(context.Context, *state.SetRequest) error
        +Delete(context.Context, *state.DeleteRequest) error
        +BulkGet(context.Context, []state.GetRequest, state.BulkGetOpts) ([]state.BulkGetResponse, error)
        +BulkSet(context.Context, []state.SetRequest, state.BulkStoreOpts) error
        +BulkDelete(context.Context, []state.DeleteRequest, state.BulkStoreOpts) error
        +Query(context.Context, *state.QueryRequest) (*state.QueryResponse, error)
        +Features() []state.Feature
        +Close() error
    }
    
    class NebulaStateStore {
        -pool *nebula.ConnectionPool
        -config NebulaConfig
        +Init(context.Context, state.Metadata) error
        +Get(context.Context, *state.GetRequest) (*state.GetResponse, error)
        +Set(context.Context, *state.SetRequest) error
        +Delete(context.Context, *state.DeleteRequest) error
        +BulkGet(context.Context, []state.GetRequest, state.BulkGetOpts) ([]state.BulkGetResponse, error)
        +BulkSet(context.Context, []state.SetRequest, state.BulkStoreOpts) error
        +BulkDelete(context.Context, []state.DeleteRequest, state.BulkStoreOpts) error
        +Query(context.Context, *state.QueryRequest) (*state.QueryResponse, error)
        +Features() []state.Feature
        +Close() error
        +GetComponentMetadata() map[string]string
    }
    
    StateStore <|-- NebulaStateStore
```

### 5. Data Storage Model

```mermaid
erDiagram
    SPACE ||--o{ VERTEX : contains
    VERTEX {
        string id "Dapr state key"
        string data "JSON serialized value"
    }
    VERTEX ||--|| TAG : has
    TAG {
        string name "state"
        string data "property"
    }
```

**NebulaGraph Schema:**
- **Space**: `dapr_state`
- **Tag**: `state` with property `data`
- **Vertex ID**: Dapr state key
- **Property**: JSON-serialized state value

## Container Architecture

### 6. Multi-Container Setup

```mermaid
graph TB
    subgraph "Docker Compose Services"
        subgraph "Core Services (Default Profile)"
            A[nebulagraph-component<br/>State Store Container]
            B[daprd<br/>Dapr Runtime Container]
        end
        
        subgraph "Test Services (Test Profile)"
            C[test-app<br/>Testing Tools Container]
        end
        
        subgraph "Shared Resources"
            D[socket<br/>Unix Domain Socket Volume]
            E[nebula-net<br/>External Docker Network]
        end
        
        subgraph "Configuration"
            F[component.yml<br/>Component Definition]
        end
    end
    
    A <--> D
    B <--> D
    A --> E
    B --> E
    C --> E
    B --> F
    
    style A fill:#e8f5e8
    style B fill:#f3e5f5
    style C fill:#fff3e0
    style D fill:#f1f8e9
    style E fill:#f1f8e9
    style F fill:#fff3e0
```

### 7. Volume Mounting Strategy

```yaml
# docker-compose.yml excerpt
volumes:
  socket:  # Shared Unix Domain Socket

services:
  nebulagraph-component:
    volumes:
      - socket:/var/run  # Component writes socket
      
  daprd:
    volumes:
      - socket:/var/run  # Dapr reads socket
      - component.yml:/components/component.yml  # Configuration
```

## Request Processing Flow

### 8. State Operations Sequence

```mermaid
sequenceDiagram
    participant C as Client
    participant D as Dapr Runtime
    participant S as Unix Socket
    participant N as NebulaGraph Component
    participant G as NebulaGraph DB
    
    Note over C,G: SET Operation
    C->>D: POST /v1.0/state/nebulagraph-state
    D->>S: gRPC SetState Request
    S->>N: Forward Request
    N->>N: Validate & Process
    N->>G: INSERT VERTEX state(data) VALUES 'key':('value')
    G-->>N: Success Response
    N-->>S: gRPC Response
    S-->>D: Success
    D-->>C: HTTP 204 No Content
    
    Note over C,G: GET Operation
    C->>D: GET /v1.0/state/nebulagraph-state/key
    D->>S: gRPC GetState Request
    S->>N: Forward Request
    N->>G: MATCH (v:state) WHERE id(v) = 'key' RETURN v.data
    G-->>N: Data Response
    N-->>S: gRPC Response with Data
    S-->>D: State Data
    D-->>C: HTTP 200 with JSON
```

## Feature Support

### 9. Implemented Features

```mermaid
graph LR
    subgraph "Dapr State Store Features"
        A[Basic CRUD Operations]
        B[Bulk Operations]
        C[ETag Support]
        D[Transactional Support]
        E[Query API]
    end
    
    subgraph "NebulaGraph Benefits"
        F[Graph Relationships]
        G[High Performance]
        H[Distributed Storage]
        I[ACID Compliance]
    end
    
    A --> F
    B --> G
    C --> H
    D --> I
    E --> F
    
    style A fill:#e8f5e8
    style B fill:#e8f5e8
    style C fill:#e8f5e8
    style D fill:#e8f5e8
    style E fill:#e8f5e8
```

**Supported Features:**
- ✅ `FeatureETag` - Optimistic concurrency control
- ✅ `FeatureTransactional` - ACID transactions
- ✅ `FeatureQueryAPI` - Advanced querying capabilities

## Testing Architecture

### 10. Comprehensive Test Coverage

```mermaid
graph TD
    A[test_all.sh<br/>Main Test Orchestrator] --> B[HTTP API Tests]
    A --> C[gRPC API Tests]
    
    B --> B1[Prerequisites Check]
    B --> B2[SET Operations]
    B --> B3[GET Operations]
    B --> B4[BULK Operations]
    B --> B5[DELETE Operations]
    B --> B6[Cleanup Verification]
    
    C --> C1[gRPC Service Discovery]
    C --> C2[gRPC CRUD Operations]
    C --> C3[Cross-Protocol Tests]
    C --> C4[Error Handling]
    
    subgraph "Test Tools"
        D[curl - HTTP testing]
        E[grpcurl - gRPC testing]
        F[jq - JSON processing]
    end
    
    B1 --> D
    C1 --> E
    B3 --> F
    
    style A fill:#fff3e0
    style B fill:#e1f5fe
    style C fill:#e8f5e8
```

## Security & Isolation

### 11. Security Boundaries

```mermaid
graph TB
    subgraph "Network Security"
        A[External Access] --> B[Published Ports Only<br/>3501, 50001]
        B --> C[Dapr Runtime Container]
        C --> D[Internal Docker Network<br/>nebula-net]
    end
    
    subgraph "Process Isolation"
        E[Host System] --> F[Container Runtime]
        F --> G[Isolated Namespaces]
        G --> H[Component Process]
        G --> I[Dapr Process]
    end
    
    subgraph "Communication Security"
        J[Unix Domain Socket] --> K[Local File System]
        K --> L[Volume Mount]
        L --> M[Shared Between Containers]
    end
    
    style A fill:#ffcdd2
    style B fill:#e1f5fe
    style D fill:#f1f8e9
    style H fill:#e8f5e8
    style I fill:#f3e5f5
    style J fill:#f1f8e9
```

## Performance Characteristics

### 12. Performance Optimizations

- **Connection Pooling**: Reuses NebulaGraph connections
- **Unix Socket Communication**: Faster than TCP networking
- **Batch Operations**: Efficient bulk processing
- **Stateless Design**: Horizontal scaling capability
- **Memory Efficient**: Distroless container base image

## Deployment Considerations

### 13. Production Deployment

```yaml
# Example production configuration
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: nebulagraph-state
spec:
  type: state.nebulagraph-state
  version: v1
  metadata:
  - name: hosts
    value: "nebula-cluster-lb.internal"
  - name: port
    value: "9669"
  - name: username
    secretKeyRef:
      name: nebula-credentials
      key: username
  - name: password
    secretKeyRef:
      name: nebula-credentials
      key: password
  - name: space
    value: "production_state"
```

This architecture provides a robust, scalable, and maintainable solution for integrating NebulaGraph with Dapr's state management capabilities.
