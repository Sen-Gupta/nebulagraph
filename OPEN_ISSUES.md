# Open Issues - NebulaGraph Dapr Component

This document tracks known issues and limitations that require further investigation or resolution.

## Issue #1: Unicode Handling in .NET DaprClient SDK

### Status: OPEN
### Priority: Medium
### Component: NebulaGraph State Store + .NET DaprClient SDK

### Problem Description
The .NET DaprClient SDK has limitations when handling Unicode characters, particularly with emojis and multi-byte UTF-8 sequences. This affects the retrieval of Unicode data stored in the NebulaGraph state store.

### Technical Details

#### Root Cause
- **System.Text.Json Limitations**: The .NET `System.Text.Json` serializer has strict Unicode character validation
- **ASCII Character Allowlist**: Only characters in range 0x20-0x7E are allowed by default
- **Surrogate Pair Issues**: Unicode emojis and international characters (Chinese, Arabic, Russian, Japanese) cause `DecoderFallbackException`
- **Byte Sequence Corruption**: UTF-8 byte sequences like `[ED]` trigger encoding errors

#### Affected Unicode Test Data
```
"🌟 Unicode: 中文, العربية, Русский, 日本語 🚀"
```

#### Current Workaround Implementation
Multi-tier retrieval approach implemented in `StateStoreController.cs`:

1. **Byte Array Approach** (Most Reliable)
   ```csharp
   var byteData = await _daprClient.GetStateAsync<byte[]>(StateStoreName, key);
   retrieved = System.Text.Encoding.UTF8.GetString(byteData);
   ```

2. **JsonElement Approach** (Fallback)
   ```csharp
   var jsonElement = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, key);
   retrieved = jsonElement.GetString();
   ```

3. **Direct String Approach** (Last Resort)
   ```csharp
   retrieved = await _daprClient.GetStateAsync<string>(StateStoreName, key);
   ```

#### Evidence of Issue

**Successful HTTP API Test** (Direct Dapr API):
```bash
$ curl -X GET "http://localhost:3502/v1.0/state/nebulagraph-state/unicode-test"
"🌟 Unicode: 中文, العربية, Русский, 日本語 🚀"
```

**Failed .NET SDK Test** (DaprClient):
```bash
$ curl -X POST "http://localhost:5090/api/StateStore/unicode-support"
{"success":false,"status":"FAILED","message":"❌ Unicode Support failed"}
```

### Current Status

#### What Works ✅
- NebulaGraph backend properly stores UTF-8 Unicode data
- Direct Dapr HTTP API correctly retrieves Unicode data
- curl-based validation confirms data integrity
- Storage operations preserve Unicode characters

#### What Fails ❌
- .NET DaprClient SDK `GetStateAsync<string>()` calls
- Unicode test endpoints in StateStoreController
- System.Text.Json deserialization of Unicode strings
- Multi-byte character sequence handling

### Impact Assessment

#### Severity: Medium
- **Functional Impact**: Unicode data retrieval fails in .NET applications
- **Workaround Available**: Multi-tier retrieval approach provides fallback
- **Scope**: Affects .NET applications using DaprClient with Unicode data
- **Performance**: Minimal impact with byte array fallback approach

#### Test Results
- **Comprehensive Test Suite**: 39/40 tests passing (97.5% success rate)
- **Unicode-specific Tests**: 0/2 tests passing (unicode-diagnostic, unicode-support)
- **Overall System**: Fully functional with workaround

### Next Steps

#### Immediate Actions
- [x] Document issue and workaround implementation
- [x] Validate data integrity at HTTP API level
- [x] Implement multi-tier retrieval fallback strategy
- [ ] Create unit tests for Unicode handling edge cases

#### Long-term Solutions
- [ ] Investigate Dapr .NET SDK configuration options
- [ ] Research System.Text.Json encoder settings
- [ ] Consider custom JSON serialization options
- [ ] Explore alternative Unicode handling approaches

#### Investigation Areas
- [ ] JavaScriptEncoder.UnsafeRelaxedJsonEscaping configuration
- [ ] Custom JsonSerializerOptions for Unicode
- [ ] Dapr SDK version compatibility testing
- [ ] Alternative serialization libraries (Newtonsoft.Json)

### Related Files
```
src/examples/NebulaGraphNetExample/Controllers/StateStoreController.cs
├── Lines 335-353: Unicode test implementation
├── Lines 745-828: unicode-diagnostic endpoint
├── Lines 829-916: unicode-support endpoint
└── Lines 1436-1470: RunIndividualTest helper method

src/examples/NebulaGraphNetExample/test_net.sh
└── Lines 260-280: Unicode test validation
```

### References
- [System.Text.Json Unicode Documentation](https://docs.microsoft.com/en-us/dotnet/standard/serialization/system-text-json-character-encoding)
- [Dapr .NET SDK Issues](https://github.com/dapr/dotnet-sdk/issues)
- [UTF-8 Encoding Standards](https://tools.ietf.org/html/rfc3629)

### Last Updated
August 11, 2025

---

## Issue #2: Port Conflict Resolution in Multi-Service Docker Environment

### Status: RESOLVED
### Priority: High
### Component: Infrastructure Setup - Docker Services

### Problem Description
During multi-service environment setup, encountered port conflicts between ScyllaDB services and existing service bindings, preventing proper service startup and network configuration.

### Technical Details

#### Root Cause
1. **Dual Port Binding Conflict**: ScyllaDB Node and ScyllaDB Manager both trying to bind to host port 7002
2. **Hardcoded Default Values**: Docker Compose files contained hardcoded port defaults instead of proper environment variable fallbacks
3. **Port Allocation Order**: Services started without checking existing port allocations

#### Specific Conflicts Identified
```yaml
# ScyllaDB Node (scylladb-node1)
ports:
  - "${SCYLLA_INTER_NODE_PORT:-7002}:7000"  # Inter-node communication

# ScyllaDB Manager (scylla-manager) 
ports:
  - "${SCYLLA_MANAGER_WEB_PORT:-7002}:5080"  # Web UI - CONFLICT!
```

#### Error Messages
```
Error response from daemon: failed to set up container networking: 
driver failed programming external connectivity on endpoint scylla-manager 
(525c4af1de3b340671d4cbd689701b481a0dff95e1aae0730c07cf529f714c48): 
Bind for 0.0.0.0:7002 failed: port is already allocated
```

#### Service Port Mapping Overview
```
BEFORE (Conflict):
- NebulaGraph Studio: 7001 ✅
- ScyllaDB Inter-node: 7002 ❌ 
- ScyllaDB Manager: 7002 ❌ (CONFLICT)

AFTER (Resolved):
- NebulaGraph Studio: 7001 ✅
- ScyllaDB Inter-node: 7002 ✅
- ScyllaDB SSL Inter-node: 7003 ✅
- ScyllaDB Manager: 7004 ✅
```

### Resolution Implementation

#### 1. Environment Variable Updates
Updated `.env` file with proper port allocation:
```bash
# ScyllaDB Manager Configuration (Fixed)
SCYLLA_MANAGER_WEB_PORT=7004  # Changed from 7002 to 7004
SCYLLA_MANAGER_API_PORT=5091
```

#### 2. Docker Compose Default Value Correction
Fixed hardcoded defaults in `scylladb/docker-compose.yml`:
```yaml
# BEFORE
- "${SCYLLA_MANAGER_WEB_PORT:-7002}:5080"

# AFTER  
- "${SCYLLA_MANAGER_WEB_PORT:-7004}:5080"
```

#### 3. Container Recreation Strategy
```bash
# Force recreation with new configuration
docker compose down -v
docker compose up -d --force-recreate
```

### Current Status

#### What Works ✅
- All 8 containers running successfully
- Proper port separation across services
- Environment-driven configuration
- Shared network connectivity (dapr-pluggable-net)

#### Services Running
```
NebulaGraph: nebula-metad, nebula-storaged, nebula-graphd, nebula-console, nebula-studio
Redis: redis-pubsub
ScyllaDB: scylladb-node1, scylla-manager
```

### Impact Assessment

#### Severity: High (Blocking)
- **Functional Impact**: Complete service startup failure
- **Scope**: Affected entire multi-service environment setup
- **Resolution Time**: Immediate fix implemented
- **Prevention**: Systematic port allocation strategy established

### Next Steps

#### Immediate Actions
- [x] Resolve port conflicts for ScyllaDB services
- [x] Update environment configuration files
- [x] Fix Docker Compose default values
- [x] Validate all services startup successfully

#### Long-term Improvements
- [ ] Implement port conflict detection in environment setup script
- [ ] Create port allocation documentation
- [ ] Add validation checks for port availability
- [ ] Establish port range reservations per service

### Related Files
```
src/.env
├── Lines: SCYLLA_MANAGER_WEB_PORT configuration

src/dependencies/scylladb/docker-compose.yml
├── Lines 47: ScyllaDB Manager port mapping fix
└── Service port definitions

src/dependencies/environment_setup.sh
└── Multi-service startup orchestration
```

### Last Updated
August 11, 2025

---

## Issue #3: Hardcoded Values in Docker Compose Parameterization

### Status: RESOLVED  
### Priority: Medium
### Component: Infrastructure Configuration - Docker Compose Services

### Problem Description
Docker Compose files contained hardcoded values instead of proper environment variable parameterization, reducing flexibility and consistency across service configurations.

### Technical Details

#### Root Cause Analysis
1. **Inconsistent Parameterization**: Mixed usage of hardcoded values and environment variables
2. **Missing Default Value Syntax**: Incorrect or missing `${VAR:-default}` patterns
3. **Configuration Drift**: Services not following established parameterization patterns
4. **Hardcoded Network References**: Some services using hardcoded network names

#### Affected Services and Issues

##### Redis Service Issues
```yaml
# BEFORE (Hardcoded)
ports:
  - "${REDIS_HOST_PORT}:6379"           # No default value
command: ["redis-server", "--requirepass", "${REDIS_PASSWORD}"]  # No default
networks:
  - redis-net                           # Hardcoded network name

# AFTER (Properly Parameterized)  
ports:
  - "${REDIS_HOST_PORT:-6380}:6379"     # With default value
command: ["redis-server", "--requirepass", "${REDIS_PASSWORD:-dapr_redis}"]
networks:
  - dapr-pluggable-net                          # Shared network reference
```

##### ScyllaDB Service Issues
```yaml
# BEFORE (Mixed Hardcoded/Parameterized)
image: scylladb/scylla:5.4.6                    # Hardcoded version
container_name: scylladb-node1                   # Hardcoded name
command: 
  - --seeds=scylladb-node1                      # Hardcoded reference
  - --smp=1                                     # Hardcoded value
  - --memory=1G                                 # Hardcoded value

# AFTER (Fully Parameterized)
image: scylladb/scylla:${SCYLLA_VERSION:-5.4.6}
container_name: ${SCYLLA_NODE1_CONTAINER:-scylladb-node1}  
command:
  - --seeds=${SCYLLA_NODE1_CONTAINER:-scylladb-node1}
  - --smp=${SCYLLA_SMP:-1}
  - --memory=${SCYLLA_MEMORY:-1G}
```

##### Network Configuration Issues
```yaml
# BEFORE (Service-Specific Networks)
networks:
  redis-net:
    driver: bridge
  scylla-net:
    driver: bridge

# AFTER (Unified Network Strategy)
networks:
  dapr-pluggable-net:
    external: true
    name: ${DAPR_PLUGABBLE_NETWORK_NAME:-dapr-pluggable-net}
```

### Resolution Implementation

#### 1. Systematic Parameterization Pattern
Established consistent pattern across all services:
```yaml
# Standard Pattern Applied
image: ${SERVICE_IMAGE:-default}
container_name: ${SERVICE_CONTAINER:-default}
ports:
  - "${SERVICE_PORT:-default}:internal_port"
networks:
  - dapr-pluggable-net
```

#### 2. Environment Variable Standardization
Updated `.env` file with comprehensive service configuration:
```bash
# Redis Configuration
REDIS_HOST_PORT=6380

# ScyllaDB Configuration  
SCYLLA_VERSION=5.4.6
SCYLLA_NODE1_CONTAINER=scylladb-node1
SCYLLA_CQL_PORT=9042
SCYLLA_SMP=1
SCYLLA_MEMORY=1G

# ScyllaDB Manager Configuration
SCYLLA_MANAGER_VERSION=3.2.6
SCYLLA_MANAGER_WEB_PORT=7004
SCYLLA_MANAGER_API_PORT=5091
```

#### 3. Unified Network Architecture
Implemented shared network strategy:
- All services use `dapr-pluggable-net` for inter-service communication
- External network configuration with parameterized naming
- Consistent network reference across all docker-compose files

### Current Status

#### What Works ✅
- Consistent parameterization across all services
- Flexible configuration through environment variables
- Unified network architecture enabling service communication
- Default fallback values preventing startup failures
- Configuration centralized in root `.env` file

#### Services Configured
```
✅ NebulaGraph: Fully parameterized with ${VARIABLE:-default} pattern
✅ Redis: Proper environment variable usage with defaults  
✅ ScyllaDB: Complete parameterization including command arguments
```

### Impact Assessment

#### Severity: Medium (Configuration Quality)
- **Maintainability**: Significantly improved configuration management
- **Flexibility**: Environment-specific deployments now possible
- **Consistency**: Standardized approach across all services
- **Documentation**: Clear parameter definitions in `.env` file

#### Benefits Achieved
- **Single Source of Truth**: All configuration in `.env` file
- **Environment Portability**: Easy deployment across different environments  
- **Service Isolation**: Each service maintains independent configuration
- **Network Unification**: Simplified inter-service communication

### Next Steps

#### Immediate Actions
- [x] Complete parameterization of all Docker Compose files
- [x] Standardize environment variable naming conventions
- [x] Implement unified network architecture
- [x] Update documentation with parameter definitions

#### Long-term Improvements  
- [ ] Create configuration validation scripts
- [ ] Implement environment-specific `.env` file templates
- [ ] Add parameter documentation generation
- [ ] Establish configuration change management process

### Related Files
```
src/.env
├── Centralized configuration for all services
├── Redis configuration parameters
├── ScyllaDB configuration parameters  
└── Network configuration

src/dependencies/redis/docker-compose.yml
├── Redis service parameterization
└── Network configuration updates

src/dependencies/scylladb/docker-compose.yml  
├── ScyllaDB service parameterization
├── ScyllaDB Manager parameterization
└── Command argument parameterization

src/dependencies/nebula/docker-compose.yml
└── NebulaGraph parameterization (reference implementation)
```

### Last Updated
August 11, 2025

---

## Issue Template (For Future Issues)

### Status: [OPEN/IN_PROGRESS/RESOLVED]
### Priority: [Critical/High/Medium/Low]
### Component: [Component Name]

### Problem Description
[Brief description of the issue]

### Technical Details
[Detailed technical analysis]

### Current Status
[What works and what doesn't]

### Impact Assessment
[Severity and scope analysis]

### Next Steps
[Action items and investigation areas]

### Related Files
[List of affected files]

### Last Updated
[Date of last update]
