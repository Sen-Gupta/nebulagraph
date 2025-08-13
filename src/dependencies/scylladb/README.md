# ScyllaDB Infrastructure

ScyllaDB cluster setup for Dapr component development.

## Quick Commands

```bash
# From dependencies/ directory  
./environment_setup.sh start    # Start all services (including ScyllaDB)
./environment_setup.sh status   # Check ScyllaDB cluster status
./environment_setup.sh stop     # Stop all services
./environment_setup.sh clean    # Reset and clean environment
```

## What's Included

- **ScyllaDB Cluster**: Multi-node cluster with automatic initialization
- **ScyllaDB Manager**: Web UI available at http://localhost:5081
- **Health Checks**: Automatic readiness verification  
- **Schema Setup**: `dapr_state` keyspace and `state` table created automatically

## Cluster Services

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| ScyllaDB Node | scylladb-node1 | 9042 | CQL native protocol |
| ScyllaDB Manager | scylladb-manager | 5081 | Web management interface |
| Redis | redis-pubsub | 6381 | Pub/sub for component coordination |

## Database Schema

```sql
-- Keyspace
CREATE KEYSPACE dapr_state 
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

-- State table
CREATE TABLE dapr_state.state (
    key text PRIMARY KEY,
    value text,
    etag text,
    last_modified timestamp
);
```

## Direct Access

```bash
# Connect via cqlsh (requires ScyllaDB tools)
cqlsh localhost 9042

# Example queries  
USE dapr_state;
DESCRIBE TABLES;
SELECT * FROM state LIMIT 10;
```

- **Web UI**: http://localhost:5081 (ScyllaDB Manager - updated port)
- **CQL Shell**: `docker exec -it scylladb-node1 cqlsh`
- **Logs**: `docker-compose logs -f scylladb-node1`

## Stop and Cleanup

```bash
# Stop services
docker-compose down

# Remove volumes (data will be lost)
docker-compose down -v
```

## Network

The services run on the `scylla-net` bridge network, allowing communication between containers.
