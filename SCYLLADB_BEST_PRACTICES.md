# ScyllaDB Best Practices

## Configuration Optimization

### Keyspace Settings
```sql
CREATE KEYSPACE dapr_state 
WITH replication = {
    'class': 'NetworkTopologyStrategy', 
    'datacenter1': 3  -- Use NetworkTopologyStrategy for production
};
```

### Table Design
```sql
-- Optimized for state store operations
CREATE TABLE state (
    key text PRIMARY KEY,
    value text,
    etag text,
    last_modified timestamp
) WITH 
    compaction = {'class': 'LeveledCompactionStrategy'}
    AND gc_grace_seconds = 864000;  -- 10 days for tombstone cleanup
```

## Performance Tuning

### Connection Pool Settings
- **Connections**: 4-8 per core
- **Max Requests per Connection**: 1024
- **Request Timeout**: 10-30 seconds
- **Connection Timeout**: 5-10 seconds

### Query Optimization
- Use prepared statements for repeated queries
- Leverage token-aware routing
- Implement proper pagination for large result sets
- Use appropriate consistency levels (LOCAL_QUORUM for production)

## Monitoring

### Key Metrics
- **Latency**: p95, p99 for read/write operations
- **Throughput**: Operations per second
- **Cache Hit Ratio**: Row cache and key cache
- **Compaction**: Pending compactions and space amplification
- **Errors**: Timeout and connection errors

### Health Checks
```bash
# Node health
nodetool status

# Table statistics  
nodetool tablestats dapr_state.state

# Performance metrics
nodetool tpstats
```
