# Dapr Component Architecture - Standard Documentation Approach

## Application + Sidecar Pattern: Built-in vs Pluggable Components

Following standard Dapr and Docker documentation patterns:

### Built-in Component Architecture (Traditional)

```mermaid
graph TB
    subgraph "Application Container"
        A1[Your Application]
        A2[Dapr SDK]
    end
    
    subgraph "Dapr Sidecar Container"
        S1[Dapr Runtime - daprd]
        S2[HTTP/gRPC APIs]
        S3[Built-in Components]
        S4[Redis State Store]
        S5[Cosmos DB State Store]
        S6[SQL Server State Store]
    end
    
    subgraph "External Infrastructure"
        E1[Redis Cluster]
        E2[Cosmos DB]
        E3[SQL Server]
    end
    
    A2 --> S2
    S1 --> S3
    S3 --> S4
    S3 --> S5
    S3 --> S6
    S4 --> E1
    S5 --> E2
    S6 --> E3
    
    style A1 fill:#e3f2fd
    style S1 fill:#f3e5f5
    style S4 fill:#ffecb3
    style S5 fill:#ffecb3
    style S6 fill:#ffecb3
```

### Pluggable Component Architecture (Our Implementation)

```mermaid
graph TB
    subgraph "Application Container"
        A1[Your Application]
        A2[Dapr SDK]
    end
    
    subgraph "Dapr Sidecar Container"
        S1[Dapr Runtime - daprd]
        S2[HTTP/gRPC APIs]
        S3[Component Loader]
        S4[Unix Socket Interface]
    end
    
    subgraph "NebulaGraph Component Container"
        C1[NebulaGraph Component]
        C2[State Store Interface]
        C3[gRPC Service]
        C4[NebulaGraph Go Client]
    end
    
    subgraph "Shared Volume"
        V1[Unix Domain Socket<br/>/var/run]
    end
    
    subgraph "External Infrastructure"
        N1[NebulaGraph Cluster]
        N2[Graph Database]
        N3[Meta Service]
        N4[Storage Service]
    end
    
    A2 --> S2
    S1 --> S3
    S3 <--> V1
    C3 <--> V1
    C1 --> C2
    C4 --> N1
    N1 --> N2
    N1 --> N3
    N1 --> N4
    
    style A1 fill:#e3f2fd
    style S1 fill:#f3e5f5
    style C1 fill:#e8f5e8
    style V1 fill:#f1f8e9
    style N1 fill:#fce4ec
```

## Key Architectural Differences

### Built-in Components
- **Single Process**: Everything runs inside Dapr runtime
- **Language Constraint**: Must be written in Go
- **Release Coupling**: Updates tied to Dapr releases
- **Resource Sharing**: Shares memory/CPU with Dapr runtime
- **Distribution**: Bundled with Dapr installation

### Pluggable Components (Our Architecture)
- **Process Isolation**: Separate process/container
- **Language Freedom**: Any gRPC-supported language
- **Independent Releases**: Own versioning and deployment cycle
- **Resource Isolation**: Dedicated container resources
- **Custom Distribution**: Standalone container images

## Standard Application + Sidecar Communication Pattern

```mermaid
sequenceDiagram
    participant App as Your Application
    participant SDK as Dapr SDK
    participant Sidecar as Dapr Sidecar
    participant Socket as Unix Socket
    participant Component as NebulaGraph Component
    participant DB as NebulaGraph Database
    
    Note over App,DB: Application Startup & Component Discovery
    
    Component->>Socket: Start Component gRPC Server
    Component->>Socket: Register State Store Service
    
    Sidecar->>Socket: Discover Available Components
    Sidecar->>Component: Request Component Metadata
    Component-->>Sidecar: Return Service Information
    
    Sidecar->>Component: Send Configuration (component.yaml)
    Component->>Component: Initialize with Metadata
    Component->>DB: Establish Connection Pool
    DB-->>Component: Connections Ready
    Component-->>Sidecar: Component Ready Signal
    
    Note over App,DB: Runtime State Operations
    
    App->>SDK: SaveState(key, value)
    SDK->>Sidecar: HTTP POST /v1.0/state/statestore
    Sidecar->>Component: gRPC SetState Request
    Component->>DB: INSERT VERTEX state(data) VALUES key:(value)
    DB-->>Component: Operation Success
    Component-->>Sidecar: gRPC Success Response
    Sidecar-->>SDK: HTTP 204 No Content
    SDK-->>App: State Saved Successfully
    
    App->>SDK: GetState(key)
    SDK->>Sidecar: HTTP GET /v1.0/state/statestore/key
    Sidecar->>Component: gRPC GetState Request
    Component->>DB: MATCH (v:state) WHERE id(v) = key RETURN v.data
    DB-->>Component: Return Data
    Component-->>Sidecar: gRPC Response with Data
    Sidecar-->>SDK: HTTP 200 with JSON Data
    SDK-->>App: Return State Value
```

## Standard Docker Compose - Application + Sidecar + Component

```mermaid
graph TB
    subgraph "Docker Host Environment"
        subgraph "Application Tier"
            APP[Your Application Container<br/>your-app:latest]
            APP_ENV[Environment:<br/>DAPR_HTTP_ENDPOINT<br/>DAPR_GRPC_ENDPOINT]
        end
        
        subgraph "Dapr Sidecar Tier"
            SIDECAR[Dapr Sidecar Container<br/>ghcr.io/dapr/daprd:latest]
            HTTP_PORT[Published Port :3501]
            GRPC_PORT[Published Port :50001]
            CONFIG_VOL[Component Config Volume<br/>./components:/components]
        end
        
        subgraph "Component Tier"
            NEBULA_COMP[NebulaGraph Component Container<br/>Built from Dockerfile]
            COMP_ENV[Environment:<br/>DAPR_COMPONENT_SOCKETS_FOLDER]
        end
        
        subgraph "Shared Resources"
            SOCKET_VOL[Socket Volume<br/>socket-volume:/var/run]
        end
        
        subgraph "Networks"
            APP_NET[app-network<br/>Internal Communication]
            NEBULA_NET[nebula-network<br/>External Database Access]
        end
        
        subgraph "External Infrastructure"
            NEBULA_DB[NebulaGraph Database<br/>External Network]
        end
    end
    
    APP --> APP_ENV
    APP --> SIDECAR
    SIDECAR --> HTTP_PORT
    SIDECAR --> GRPC_PORT
    SIDECAR --> CONFIG_VOL
    SIDECAR <--> SOCKET_VOL
    NEBULA_COMP <--> SOCKET_VOL
    NEBULA_COMP --> COMP_ENV
    
    APP --> APP_NET
    SIDECAR --> APP_NET
    NEBULA_COMP --> APP_NET
    NEBULA_COMP --> NEBULA_NET
    NEBULA_NET --> NEBULA_DB
    
    style APP fill:#e3f2fd
    style SIDECAR fill:#f3e5f5
    style NEBULA_COMP fill:#e8f5e8
    style SOCKET_VOL fill:#f1f8e9
    style NEBULA_DB fill:#fce4ec
```

## Standard State Management Flow - Application Perspective

```mermaid
flowchart TD
    subgraph "Application Layer"
        A[Your Application<br/>Any Language]
        SDK[Dapr SDK<br/>.NET, Java, Python, Go, etc.]
    end
    
    subgraph "Dapr Sidecar Container"
        HTTP[HTTP API :3501<br/>REST Endpoints]
        GRPC[gRPC API :50001<br/>Proto Services]
        STATE[State Management<br/>Building Block]
        ROUTER[Component Router<br/>Route to State Store]
    end
    
    subgraph "Component Interface Layer"
        INTERFACE[Pluggable Component Interface<br/>Standard Contract]
        SOCKET[Unix Domain Socket<br/>IPC Communication]
    end
    
    subgraph "NebulaGraph Component Container"
        IMPL[State Store Implementation<br/>NebulaStateStore]
        HANDLER{Operation Handler}
        GET_OP[Get State Operation]
        SET_OP[Set State Operation]
        DEL_OP[Delete State Operation]
        BULK_OP[Bulk Operations]
    end
    
    subgraph "Database Infrastructure"
        POOL[NebulaGraph Connection Pool<br/>Session Management]
        CLUSTER[NebulaGraph Database<br/>Distributed Graph Store]
    end
    
    %% Application Flow
    A --> SDK
    SDK --> HTTP
    SDK --> GRPC
    HTTP --> STATE
    GRPC --> STATE
    STATE --> ROUTER
    
    %% Sidecar to Component
    ROUTER --> INTERFACE
    INTERFACE --> SOCKET
    SOCKET --> IMPL
    
    %% Component Processing
    IMPL --> HANDLER
    HANDLER -->|GET Request| GET_OP
    HANDLER -->|SET Request| SET_OP
    HANDLER -->|DELETE Request| DEL_OP
    HANDLER -->|BULK Request| BULK_OP
    
    %% Database Operations
    GET_OP --> POOL
    SET_OP --> POOL
    DEL_OP --> POOL
    BULK_OP --> POOL
    POOL --> CLUSTER
    
    style A fill:#e3f2fd
    style STATE fill:#f3e5f5
    style IMPL fill:#e8f5e8
    style CLUSTER fill:#fce4ec
    style SOCKET fill:#f1f8e9
```

## Standard Component Testing Architecture

```mermaid
graph TB
    subgraph "Test Environment Setup"
        subgraph "Test Application Container"
            TEST_APP[Test Application<br/>Integration Tests]
            HTTP_TESTS[HTTP Client Tests<br/>curl + jq]
            GRPC_TESTS[gRPC Client Tests<br/>grpcurl]
        end
        
        subgraph "Dapr Test Sidecar"
            TEST_SIDECAR[Dapr Sidecar<br/>Test Configuration]
            TEST_HTTP[HTTP API :3501<br/>Test Endpoint]
            TEST_GRPC[gRPC API :50001<br/>Test Endpoint]
        end
        
        subgraph "Component Under Test"
            COMP_TEST[NebulaGraph Component<br/>Same as Production]
            STATE_IMPL[State Store Implementation<br/>Production Code]
        end
        
        subgraph "Test Infrastructure"
            TEST_DB[NebulaGraph Test Database<br/>Isolated Test Data]
            TEST_SCHEMA[Test Schema<br/>dapr_state space]
        end
        
        subgraph "Test Orchestration"
            TEST_RUNNER[test_all.sh<br/>Test Orchestrator]
            HTTP_SUITE[test_component.sh<br/>HTTP Test Suite]
            GRPC_SUITE[test_component_grpc.sh<br/>gRPC Test Suite]
        end
    end
    
    TEST_RUNNER --> HTTP_SUITE
    TEST_RUNNER --> GRPC_SUITE
    HTTP_SUITE --> HTTP_TESTS
    GRPC_SUITE --> GRPC_TESTS
    HTTP_TESTS --> TEST_HTTP
    GRPC_TESTS --> TEST_GRPC
    TEST_SIDECAR <--> COMP_TEST
    STATE_IMPL --> TEST_DB
    TEST_DB --> TEST_SCHEMA
    
    style TEST_APP fill:#fff3e0
    style TEST_SIDECAR fill:#f3e5f5
    style COMP_TEST fill:#e8f5e8
    style TEST_DB fill:#fce4ec
    style TEST_RUNNER fill:#fff3e0
```

## Standard Docker Compose Configuration Example

```yaml
# Following Standard Dapr Documentation Pattern
version: '3.8'

services:
  # Your Application (Example)
  my-application:
    image: my-app:latest
    container_name: my-application
    environment:
      - DAPR_HTTP_ENDPOINT=http://dapr-sidecar:3501
      - DAPR_GRPC_ENDPOINT=dapr-sidecar:50001
    depends_on:
      - dapr-sidecar
    networks:
      - app-network

  # Standard Dapr Sidecar
  dapr-sidecar:
    image: "ghcr.io/dapr/daprd:latest"
    container_name: dapr-sidecar
    command: |
      ./daprd 
      --app-id my-application
      --dapr-http-port 3501 
      --dapr-grpc-port 50001
      --components-path /components
      --log-level info
    environment:
      - DAPR_COMPONENTS_SOCKETS_FOLDER=/var/run
    ports:
      - "3501:3501"  # HTTP API
      - "50001:50001"  # gRPC API
    volumes:
      - components-socket:/var/run
      - ./components:/components:ro
    depends_on:
      - nebulagraph-component
    networks:
      - app-network

  # NebulaGraph Pluggable Component
  nebulagraph-component:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: nebulagraph-state-component
    environment:
      - DAPR_COMPONENT_SOCKETS_FOLDER=/var/run
    volumes:
      - components-socket:/var/run
    networks:
      - app-network
      - nebula-network

  # Test Container (Optional - for CI/CD)
  component-tests:
    build:
      context: .
      dockerfile: Dockerfile.test
    container_name: component-tests
    environment:
      - DAPR_HTTP_ENDPOINT=http://dapr-sidecar:3501
      - DAPR_GRPC_ENDPOINT=dapr-sidecar:50001
    depends_on:
      - dapr-sidecar
    networks:
      - app-network
    profiles:
      - test

volumes:
  components-socket:

networks:
  app-network:
    driver: bridge
  nebula-network:
    external: true
    name: nebula-net
```

This standard architecture follows official Dapr and Docker documentation patterns, making it easy to understand, deploy, and maintain in production environments.
