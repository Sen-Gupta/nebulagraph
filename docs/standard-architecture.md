# NebulaGraph Dapr Component - Standard Architecture Documentation

## Application + Sidecar Pattern Architecture

Following the standard Dapr documentation approach, our architecture implements the **Application + Sidecar** pattern with **Pluggable Components**.

### 1. Standard Dapr Application Architecture

```mermaid
graph TB
    subgraph "Client/Application Layer"
        APP[Your Application]
        SDK[Dapr SDK / HTTP Client]
    end
    
    subgraph "Dapr Sidecar Pattern"
        SIDECAR[Dapr Sidecar<br/>daprd]
        API_HTTP[HTTP API :3501]
        API_GRPC[gRPC API :50001]
    end
    
    subgraph "Component Layer"
        COMPONENT[NebulaGraph<br/>State Store Component]
    end
    
    subgraph "Infrastructure Layer"
        NEBULA[NebulaGraph Database<br/>Cluster]
    end
    
    APP --> SDK
    SDK --> API_HTTP
    SDK --> API_GRPC
    API_HTTP --> SIDECAR
    API_GRPC --> SIDECAR
    SIDECAR <--> COMPONENT
    COMPONENT --> NEBULA
    
    style APP fill:#e3f2fd
    style SIDECAR fill:#f3e5f5
    style COMPONENT fill:#e8f5e8
    style NEBULA fill:#fce4ec
```

### 2. Container Architecture - Application + Sidecar + Component

```mermaid
graph TB
    subgraph "Docker Host"
        subgraph "Application Container"
            A1[Your Application]
            A2[Business Logic]
            A3[Dapr SDK]
        end
        
        subgraph "Dapr Sidecar Container"
            S1[Dapr Runtime - daprd]
            S2[Building Block APIs]
            S3[Component Discovery]
            S4[Service Invocation]
            S5[State Management]
        end
        
        subgraph "NebulaGraph Component Container"
            C1[Pluggable Component]
            C2[State Store Interface]
            C3[gRPC Service]
            C4[NebulaGraph Client]
        end
        
        subgraph "Shared Resources"
            V1[Unix Socket Volume<br/>/var/run]
            V2[Component Config<br/>component.yaml]
        end
        
        subgraph "External Infrastructure"
            N1[NebulaGraph Cluster]
            N2[Meta Service]
            N3[Storage Service]
            N4[Graph Service]
        end
    end
    
    A3 --> S2
    S1 --> S3
    S3 <--> V1
    C3 <--> V1
    S1 --> V2
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

### 3. Component Registration Flow (Standard Dapr Pattern)

```mermaid
sequenceDiagram
    participant App as Application
    participant Sidecar as Dapr Sidecar
    participant Socket as Unix Socket
    participant Component as NebulaGraph Component
    participant Config as Component Config
    participant Nebula as NebulaGraph DB
    
    Note over App,Nebula: 1. Component Startup & Registration
    
    Component->>Socket: Start gRPC Server
    Component->>Socket: Advertise State Store Service
    
    Sidecar->>Config: Load component.yaml
    Sidecar->>Socket: Discover Components
    Sidecar->>Component: Request Component Info
    Component-->>Sidecar: Return Service Metadata
    
    Note over App,Nebula: 2. Component Initialization
    
    Sidecar->>Component: Send Configuration (Init)
    Component->>Component: Parse Metadata
    Component->>Nebula: Establish Connection Pool
    Nebula-->>Component: Connection Ready
    Component-->>Sidecar: Component Ready
    
    Note over App,Nebula: 3. Application Runtime
    
    App->>Sidecar: State API Request
    Sidecar->>Component: gRPC State Operation
    Component->>Nebula: Graph Query/Update
    Nebula-->>Component: Operation Result
    Component-->>Sidecar: gRPC Response
    Sidecar-->>App: API Response
```

### 4. Standard Docker Compose - Sidecar Pattern

```yaml
# Standard Dapr Application + Sidecar + Component Pattern
version: '3.8'

services:
  # Your Application Container
  app:
    image: your-app:latest
    container_name: my-application
    environment:
      - DAPR_HTTP_ENDPOINT=http://dapr-sidecar:3501
      - DAPR_GRPC_ENDPOINT=dapr-sidecar:50001
    depends_on:
      - dapr-sidecar
    networks:
      - app-network

  # Dapr Sidecar Container
  dapr-sidecar:
    image: "ghcr.io/dapr/daprd:latest"
    container_name: dapr-sidecar
    command: |
      ./daprd 
      --app-id my-app 
      --dapr-http-port 3501 
      --dapr-grpc-port 50001
      --components-path /components
      --log-level debug
    environment:
      - DAPR_COMPONENTS_SOCKETS_FOLDER=/var/run
    ports:
      - "3501:3501"  # Dapr HTTP API
      - "50001:50001"  # Dapr gRPC API
    volumes:
      - socket-volume:/var/run
      - ./components:/components
    depends_on:
      - nebulagraph-component
    networks:
      - app-network

  # NebulaGraph Pluggable Component
  nebulagraph-component:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: nebulagraph-component
    environment:
      - DAPR_COMPONENT_SOCKETS_FOLDER=/var/run
    volumes:
      - socket-volume:/var/run
    networks:
      - app-network
      - nebula-network

volumes:
  socket-volume:

networks:
  app-network:
  nebula-network:
    external: true
```

### 5. State Management Flow - Standard Pattern

```mermaid
flowchart TD
    subgraph "Application Layer"
        A[Your Application]
        B[Dapr SDK]
    end
    
    subgraph "Dapr Sidecar"
        C[HTTP/gRPC APIs]
        D[State Management Building Block]
        E[Component Router]
    end
    
    subgraph "Component Interface"
        F[Pluggable Component Interface]
        G[Unix Socket Communication]
    end
    
    subgraph "NebulaGraph Component"
        H[State Store Implementation]
        I{Operation Handler}
        J[Get State]
        K[Set State]
        L[Delete State]
        M[Bulk Operations]
    end
    
    subgraph "Database Layer"
        N[NebulaGraph Connection Pool]
        O[Graph Database]
    end
    
    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    H --> I
    
    I -->|GET| J
    I -->|SET| K
    I -->|DELETE| L
    I -->|BULK| M
    
    J --> N
    K --> N
    L --> N
    M --> N
    N --> O
    
    style A fill:#e3f2fd
    style D fill:#f3e5f5
    style H fill:#e8f5e8
    style O fill:#fce4ec
```

### 6. Component Configuration - Standard Approach

```yaml
# Standard Dapr Component Configuration
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
  namespace: default
spec:
  type: state.nebulagraph-state
  version: v1
  metadata:
  # Connection Configuration
  - name: hosts
    value: "nebula-graphd-1,nebula-graphd-2,nebula-graphd-3"
  - name: port
    value: "9669"
  - name: username
    value: "root"
  - name: password
    secretKeyRef:
      name: nebula-secret
      key: password
  - name: space
    value: "dapr_state"
  
  # Performance Configuration  
  - name: connectionTimeout
    value: "10s"
  - name: executionTimeout
    value: "30s"
  - name: maxConnections
    value: "100"
```

### 7. Application Usage Pattern

```mermaid
sequenceDiagram
    participant App as Your Application
    participant SDK as Dapr SDK
    participant Sidecar as Dapr Sidecar
    participant Component as NebulaGraph Component
    participant DB as NebulaGraph
    
    Note over App,DB: Standard Dapr State Store Usage
    
    App->>SDK: SaveState("user-123", userData)
    SDK->>Sidecar: POST /v1.0/state/statestore
    Sidecar->>Component: gRPC SetState()
    Component->>DB: INSERT VERTEX state(data) VALUES 'user-123':(userData)
    DB-->>Component: Success
    Component-->>Sidecar: gRPC Response
    Sidecar-->>SDK: HTTP 204 No Content
    SDK-->>App: Success
    
    App->>SDK: GetState("user-123")
    SDK->>Sidecar: GET /v1.0/state/statestore/user-123
    Sidecar->>Component: gRPC GetState()
    Component->>DB: MATCH (v:state) WHERE id(v) = 'user-123' RETURN v.data
    DB-->>Component: userData
    Component-->>Sidecar: gRPC Response with Data
    Sidecar-->>SDK: HTTP 200 with JSON
    SDK-->>App: userData Object
```

### 8. Network Architecture - Standard Docker Pattern

```mermaid
graph TB
    subgraph "External Traffic"
        EXT[External Clients]
    end
    
    subgraph "Application Network"
        subgraph "Application Tier"
            APP[Your Application<br/>Container]
        end
        
        subgraph "Dapr Tier" 
            SIDE[Dapr Sidecar<br/>Container]
            API_H[HTTP API :3501]
            API_G[gRPC API :50001]
        end
        
        subgraph "Component Tier"
            COMP[NebulaGraph Component<br/>Container]
        end
    end
    
    subgraph "Infrastructure Network"
        GRAPH[NebulaGraph<br/>Database Cluster]
    end
    
    subgraph "Inter-Container Communication"
        SOCK[Unix Domain Socket<br/>Shared Volume]
    end
    
    EXT --> API_H
    EXT --> API_G
    APP --> SIDE
    SIDE <--> SOCK
    COMP <--> SOCK
    COMP --> GRAPH
    
    style APP fill:#e3f2fd
    style SIDE fill:#f3e5f5
    style COMP fill:#e8f5e8
    style GRAPH fill:#fce4ec
    style SOCK fill:#f1f8e9
```

### 9. Testing Architecture - Standard Approach

```mermaid
graph LR
    subgraph "Test Environment"
        subgraph "Test Application"
            T1[Test Scripts]
            T2[HTTP Client Tests]
            T3[gRPC Client Tests]
        end
        
        subgraph "Dapr Sidecar"
            S1[Test Sidecar Instance]
            S2[HTTP API :3501]
            S3[gRPC API :50001]
        end
        
        subgraph "Component Under Test"
            C1[NebulaGraph Component]
            C2[State Store Interface]
        end
        
        subgraph "Test Database"
            D1[NebulaGraph Test Instance]
        end
    end
    
    T1 --> T2
    T1 --> T3
    T2 --> S2
    T3 --> S3
    S1 <--> C1
    C2 --> D1
    
    style T1 fill:#fff3e0
    style S1 fill:#f3e5f5
    style C1 fill:#e8f5e8
    style D1 fill:#fce4ec
```

## Key Benefits of This Standard Architecture

### 🏗️ **Standard Dapr Patterns**
- **Sidecar Pattern**: Clean separation between app and infrastructure
- **Component Interface**: Standard state store contract implementation
- **Configuration-Driven**: YAML-based component configuration
- **SDK Integration**: Works with all Dapr SDKs (.NET, Java, Python, Go, etc.)

### 🔧 **Pluggable Component Benefits**
- **Language Freedom**: Component written in Go, app can be any language
- **Independent Scaling**: Scale component separately from application
- **Isolated Updates**: Update component without touching application
- **Resource Isolation**: Dedicated resources for state management

### 🚀 **Production Ready**
- **Container Orchestration**: Standard Docker/Kubernetes deployment
- **Health Monitoring**: Built-in health checks and metrics
- **Security**: Network isolation and secret management
- **High Availability**: Component clustering and failover support

This architecture follows the official Dapr documentation patterns while providing robust NebulaGraph integration through the pluggable component model.
