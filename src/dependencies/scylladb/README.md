# ScyllaDB Setup for Dapr State Store

This directory contains the Docker Compose setup for ScyllaDB to be used as a Dapr state store component.

## Components

- **ScyllaDB Node**: Primary database node running on port 9042
- **ScyllaDB Manager**: Web-based management interface on port 5080
- **Redis**: Additional Redis instance for pub/sub on port 6381

## Quick Start

1. **Start ScyllaDB cluster:**
   ```bash
   cd /home/sen/repos/nebulagraph/src/dependencies/scylladb
   docker-compose up -d
   ```

2. **Initialize the database:**
   ```bash
   ./init_scylladb.sh
   ```

3. **Check status:**
   ```bash
   docker-compose ps
   ```

## Ports

- **9042**: CQL Native Protocol (main database connection)
- **7199**: JMX monitoring
- **10000**: REST API
- **9180**: Prometheus metrics
- **7000**: Inter-node communication
- **7001**: SSL Inter-node communication
- **5080**: ScyllaDB Manager Web UI
- **5090**: ScyllaDB Manager API
- **6381**: Redis (for pub/sub)

## Database Details

- **Keyspace**: `dapr_state`
- **Table**: `state`
- **Columns**:
  - `key` (TEXT, PRIMARY KEY)
  - `value` (TEXT)
  - `etag` (TEXT)
  - `last_modified` (TIMESTAMP)

## Management

- **Web UI**: http://localhost:5080 (ScyllaDB Manager)
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
