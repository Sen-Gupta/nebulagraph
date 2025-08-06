# NebulaGraph Dapr Pluggable Component Architecture Diagrams

## 1. Overall System Architecture

```mermaid
graph TB
    subgraph "Client Applications"
        A[Dapr HTTP Client<br/>Port 3501]
        B[Dapr gRPC Client<br/>Port 50001]
    end
    
    subgraph "Docker Network: nebula-net"
        subgraph "Dapr Runtime Container"
            C[Dapr Sidecar<br/>daprd-nebulagraph]
            C1[HTTP API :3501]
            C2[gRPC API :50001]
            C3[Component Loader]
        end
        
        subgraph "NebulaGraph Component Container"
            D[NebulaGraph Pluggable Component<br/>nebulagraph-dapr-component]
            D1[gRPC Server]
            D2[State Store Implementation]
            D3[NebulaGraph Client]
        end
        
        subgraph "Test Container (Optional)"
            E[Test App<br/>test-app]
            E1[Test Scripts]
            E2[HTTP/gRPC Test Tools]
        end
        
        subgraph "NebulaGraph Infrastructure"
            F[NebulaGraph Cluster<br/>nebula-graphd:9669]
            F1[Graph Database]
            F2[Meta Service]
            F3[Storage Service]
        end
    end
    
    subgraph "Unix Domain Socket"
        G["/var/run socket<br/>Shared Volume"]
    end
    
    A --> C1
    B --> C2
    C3 --> G
    D1 --> G
    C --> F
    D3 --> F
    E --> C1
    E --> C2
    
    style A fill:#e1f5fe
    style B fill:#e1f5fe
    style C fill:#f3e5f5
    style D fill:#e8f5e8
    style E fill:#fff3e0
    style F fill:#fce4ec
    style G fill:#f1f8e9
```

## 2. Dapr Pluggable Component Communication Flow

```mermaid
sequenceDiagram
    participant Client as Dapr Client
    participant Dapr as Dapr Runtime
    participant Socket as Unix Socket
    participant Component as NebulaGraph Component
    participant Nebula as NebulaGraph DB
    
    Note over Dapr, Component: Component Registration Phase
    Component->>Socket: Start gRPC Server
    Component->>Socket: Register State Store Service
    Dapr->>Socket: Discover Components
    Dapr->>Socket: Load Component Configuration
    
    Note over Client, Nebula: Runtime Operation Phase
    Client->>Dapr: HTTP/gRPC Request (SET/GET)
    Dapr->>Socket: Forward to Component (gRPC)
    Component->>Component: Process Request
    Component->>Nebula: Execute Graph Query
    Nebula-->>Component: Query Result
    Component-->>Socket: gRPC Response
    Socket-->>Dapr: Component Response
    Dapr-->>Client: HTTP/gRPC Response
```

## 3. Container Architecture & Volume Mounting

```mermaid
graph LR
    subgraph "Host System"
        H[Docker Engine]
    end
    
    subgraph "Shared Volume"
        V["/var/run<br/>Unix Domain Socket"]
    end
    
    subgraph "Container 1: Dapr Runtime"
        D[daprd process]
        D1[Component Loader]
        D2[HTTP Server :3501]
        D3[gRPC Server :50001]
        DV["/var/run mount"]
    end
    
    subgraph "Container 2: NebulaGraph Component"
        C[component binary]
        C1[gRPC State Server]
        C2[NebulaGraph Client]
        CV["/var/run mount"]
    end
    
    subgraph "Container 3: Test App (Optional)"
        T[test scripts]
        T1[curl/grpcurl tools]
        T2[test_all.sh]
    end
    
    H --> V
    V --> DV
    V --> CV
    D1 <--> C1
    T --> D2
    T --> D3
    C2 --> N[NebulaGraph<br/>External Network]
    
    style V fill:#f1f8e9
    style DV fill:#f1f8e9
    style CV fill:#f1f8e9
```

## 4. Component Interface Implementation

```mermaid
classDiagram
    class StateStore {
        <<interface>>
        +Init(ctx, metadata) error
        +Get(ctx, request) GetResponse
        +Set(ctx, request) error
        +Delete(ctx, request) error
        +BulkGet(ctx, requests) BulkGetResponse
        +BulkSet(ctx, requests) error
        +BulkDelete(ctx, requests) error
        +Query(ctx, request) QueryResponse
        +Features() Features
        +Close() error
    }
    
    class NebulaStateStore {
        -pool ConnectionPool
        -config NebulaConfig
        +Init(ctx, metadata) error
        +Get(ctx, request) GetResponse
        +Set(ctx, request) error
        +Delete(ctx, request) error
        +BulkGet(ctx, requests) BulkGetResponse
        +BulkSet(ctx, requests) error
        +BulkDelete(ctx, requests) error
        +Query(ctx, request) QueryResponse
        +Features() Features
        +Close() error
        +GetComponentMetadata() map[string]string
    }
    
    class NebulaConfig {
        +Hosts string
        +Port string
        +Username string
        +Password string
        +Space string
    }
    
    class DaprRegistry {
        +Register(name, factory)
        +MustRun()
    }
    
    StateStore <|-- NebulaStateStore
    NebulaStateStore --> NebulaConfig
    NebulaStateStore --> DaprRegistry
```

## 5. Data Flow & State Management

```mermaid
flowchart TD
    A[Client Request] --> B{Request Type}
    
    B -->|GET| C[Retrieve State]
    B -->|SET| D[Store State]
    B -->|DELETE| E[Remove State]
    B -->|BULK| F[Batch Operations]
    
    C --> C1[Query NebulaGraph]
    C1 --> C2[MATCH vertex by key]
    C2 --> C3[Return properties]
    
    D --> D1[Prepare Insert]
    D1 --> D2[INSERT VERTEX state]
    D2 --> D3[Store key-value data]
    
    E --> E1[Prepare Delete]
    E1 --> E2[DELETE VERTEX by key]
    E2 --> E3[Remove from graph]
    
    F --> F1[Process Each Request]
    F1 --> F2[Batch Execute]
    F2 --> F3[Return Aggregated Results]
    
    C3 --> G[Format Response]
    D3 --> G
    E3 --> G
    F3 --> G
    
    G --> H[Return to Client]
    
    subgraph "NebulaGraph Database"
        I[Space: dapr_state]
        I1[Tag: state]
        I2[Property: data]
        I3[Vertex: key as ID]
    end
    
    C2 --> I
    D2 --> I
    E2 --> I
    
    style A fill:#e1f5fe
    style G fill:#e8f5e8
    style H fill:#e1f5fe
    style I fill:#fce4ec
```

## 6. Docker Compose Service Dependencies

```mermaid
graph TD
    A[nebula-net<br/>External Network] --> B[nebulagraph-component]
    A --> C[daprd]
    A --> D[test-app]
    
    B --> C
    C --> D
    
    subgraph "Component Configuration"
        E[component.yml<br/>Volume Mount]
        F[Unix Socket<br/>Volume Mount]
    end
    
    E --> C
    F --> B
    F --> C
    
    subgraph "Build Contexts"
        G[Dockerfile<br/>Component Binary]
        H[Dockerfile.test<br/>Test Tools]
    end
    
    G --> B
    H --> D
    
    subgraph "Profiles"
        I[default: component + daprd]
        J[test: + test-app]
    end
    
    I -.-> B
    I -.-> C
    J -.-> D
    
    style A fill:#f1f8e9
    style E fill:#fff3e0
    style F fill:#f1f8e9
    style I fill:#e8f5e8
    style J fill:#fff3e0
```

## 7. Component Lifecycle & Registration

```mermaid
stateDiagram-v2
    [*] --> Initializing
    
    Initializing --> Registering: Component starts
    Registering --> Configuring: Dapr discovers component
    Configuring --> Ready: Init() called with metadata
    
    Ready --> Processing: Handle requests
    Processing --> Ready: Request completed
    
    Ready --> Terminating: Shutdown signal
    Processing --> Terminating: Graceful shutdown
    Terminating --> [*]: Close() called
    
    state Registering {
        [*] --> StartGRPC
        StartGRPC --> RegisterService
        RegisterService --> AwaitDiscovery
        AwaitDiscovery --> [*]
    }
    
    state Configuring {
        [*] --> ParseMetadata
        ParseMetadata --> ConnectNebula
        ConnectNebula --> ValidateSchema
        ValidateSchema --> [*]
    }
    
    state Processing {
        [*] --> ReceiveRequest
        ReceiveRequest --> ValidateRequest
        ValidateRequest --> ExecuteOperation
        ExecuteOperation --> FormatResponse
        FormatResponse --> [*]
    }
```

## 8. Security & Network Isolation

```mermaid
graph TB
    subgraph "External Network Access"
        EXT[External Clients]
    end
    
    subgraph "Host Network Boundaries"
        subgraph "Published Ports"
            P1[3501:3501 HTTP]
            P2[50001:50001 gRPC]
        end
        
        subgraph "Docker Network: nebula-net"
            subgraph "Dapr Container"
                D[Dapr Runtime]
                D --> P1
                D --> P2
            end
            
            subgraph "Component Container"
                C[NebulaGraph Component]
            end
            
            subgraph "Test Container"
                T[Test App]
            end
        end
        
        subgraph "Unix Domain Socket"
            UDS["Shared Volume /var/run"]
        end
        
        subgraph "NebulaGraph Network"
            N[NebulaGraph Cluster]
        end
    end
    
    EXT --> P1
    EXT --> P2
    D <--> UDS
    C <--> UDS
    T --> D
    C --> N
    
    style EXT fill:#ffcdd2
    style P1 fill:#e1f5fe
    style P2 fill:#e1f5fe
    style UDS fill:#f1f8e9
    style N fill:#fce4ec
```

## Key Architecture Benefits

### 🔒 **Security**
- **Process Isolation**: Component runs in separate container
- **Network Isolation**: Internal Docker network communication
- **Socket Communication**: Unix Domain Sockets (not network ports)

### 🚀 **Performance**
- **Local Communication**: Unix sockets faster than network
- **Connection Pooling**: NebulaGraph connection pool
- **Stateless Design**: Each request is independent

### 🔄 **Scalability**
- **Independent Lifecycle**: Component updates without Dapr restart
- **Resource Management**: Container-level resource limits
- **Load Distribution**: Multiple component instances possible

### 🛠 **Maintainability**
- **Clear Separation**: Each service has single responsibility
- **Standard Interfaces**: Implements Dapr state store contract
- **Comprehensive Testing**: Automated test suite coverage

This architecture follows Dapr's pluggable component patterns and provides a robust, scalable solution for NebulaGraph integration.
