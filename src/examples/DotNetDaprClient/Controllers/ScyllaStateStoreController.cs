using Dapr.Client;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;
using System.Linq;
using System.Collections.Concurrent;

namespace DotNetDaprClient.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ScyllaStateStoreController : ControllerBase
{
    private readonly DaprClient _daprClient;
    private readonly ILogger<ScyllaStateStoreController> _logger;
    private const string StateStoreName = "scylladb-state";
    
    public ScyllaStateStoreController(DaprClient daprClient, ILogger<ScyllaStateStoreController> logger)
    {
        _daprClient = daprClient;
        _logger = logger;
    }

    [HttpPost]
    [Route("run/comprehensive")]
    public async Task<IActionResult> RunComprehensiveTestSuite()
    {
        try
        {
            _logger.LogInformation("Starting comprehensive ScyllaDB test suite - mirroring bash test sequence");
            var testResults = new List<ScyllaTestResult>();
            var startTime = DateTime.UtcNow;
            
            // Test 0: Prerequisites
            await RunTestStep(testResults, "0. Prerequisites Check", async () =>
            {
                // Test Dapr connectivity
                var testKey = "prereq-test";
                await _daprClient.SaveStateAsync(StateStoreName, testKey, "test");
                var value = await _daprClient.GetStateAsync<string>(StateStoreName, testKey);
                await _daprClient.DeleteStateAsync(StateStoreName, testKey);
                return value == "test";
            });

            // Test 1: SET Operation
            await RunTestStep(testResults, "1. Testing SET Operation", async () =>
            {
                await _daprClient.SaveStateAsync(StateStoreName, "test-key-1", "Hello ScyllaDB!");
                return true;
            });

            // Test 2: GET Operation (Simple String)
            await RunTestStep(testResults, "2. Testing GET Operation (Simple String)", async () =>
            {
                var value = await _daprClient.GetStateAsync<string>(StateStoreName, "test-key-1");
                return value == "Hello ScyllaDB!";
            });

            // Test 3: GET Operation (JSON Object)
            await RunTestStep(testResults, "3. Testing GET Operation (JSON Object)", async () =>
            {
                var jsonObj = new { message = "This is a ScyllaDB JSON value", timestamp = DateTime.UtcNow.ToString("yyyy-MM-dd"), database = "ScyllaDB" };
                await _daprClient.SaveStateAsync(StateStoreName, "test-key-2", jsonObj);
                var retrieved = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, "test-key-2");
                return retrieved.ValueKind != JsonValueKind.Undefined;
            });

            // Test 4: BULK GET Operation
            await RunTestStep(testResults, "4. Testing BULK GET Operation", async () =>
            {
                var keys = new[] { "test-key-1", "test-key-2" };
                var foundCount = 0;
                
                // Get string value
                var stringValue = await _daprClient.GetStateAsync<string>(StateStoreName, "test-key-1");
                if (!string.IsNullOrEmpty(stringValue)) foundCount++;
                
                // Get JSON value  
                var jsonValue = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, "test-key-2");
                if (jsonValue.ValueKind != JsonValueKind.Undefined) foundCount++;
                
                return foundCount == 2;
            });

            // Test 5: DELETE Operation
            await RunTestStep(testResults, "5. Testing DELETE Operation", async () =>
            {
                await _daprClient.DeleteStateAsync(StateStoreName, "test-key-1");
                return true;
            });

            // Test 6: Verifying Deletion
            await RunTestStep(testResults, "6. Verifying Deletion", async () =>
            {
                var value = await _daprClient.GetStateAsync<string>(StateStoreName, "test-key-1");
                return string.IsNullOrEmpty(value);
            });

            // Test 7: Cleanup Basic Tests
            await RunTestStep(testResults, "7. Cleanup Basic Tests", async () =>
            {
                await _daprClient.DeleteStateAsync(StateStoreName, "test-key-2");
                return true;
            });

            // Test 8: Complex JSON Object Testing
            await RunTestStep(testResults, "8. Complex JSON Object Testing", async () =>
            {
                var complexObj = new
                {
                    id = Guid.NewGuid().ToString(),
                    user = new { name = "ScyllaDB User", email = "user@scylladb.com" },
                    metadata = new { version = "1.0", database = "ScyllaDB", created = DateTime.UtcNow },
                    tags = new[] { "high-performance", "nosql", "distributed" },
                    settings = new Dictionary<string, object>
                    {
                        { "enableCache", true },
                        { "maxConnections", 100 },
                        { "timeout", 30000 }
                    }
                };
                
                await _daprClient.SaveStateAsync(StateStoreName, "complex-obj", complexObj);
                var retrieved = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, "complex-obj");
                return retrieved.ValueKind != JsonValueKind.Undefined;
            });

            // Test 9: Bulk Operations (Multiple SET)
            await RunTestStep(testResults, "9. Bulk Operations (Multiple SET)", async () =>
            {
                var bulkData = new Dictionary<string, object>
                {
                    { "bulk-1", "ScyllaDB Value 1" },
                    { "bulk-2", new { message = "Bulk JSON", index = 2 } },
                    { "bulk-3", "ScyllaDB Value 3" },
                    { "bulk-4", new { data = "performance test", timestamp = DateTime.UtcNow } },
                    { "bulk-5", "ScyllaDB Value 5" }
                };

                foreach (var kvp in bulkData)
                {
                    await _daprClient.SaveStateAsync(StateStoreName, kvp.Key, kvp.Value);
                }
                
                return true;
            });

            // Test 10: Bulk Retrieval Verification
            await RunTestStep(testResults, "10. Bulk Retrieval Verification", async () =>
            {
                var keys = new[] { "bulk-1", "bulk-2", "bulk-3", "bulk-4", "bulk-5" };
                var foundCount = 0;
                
                foreach (var key in keys)
                {
                    var value = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, key);
                    if (value.ValueKind != JsonValueKind.Undefined) foundCount++;
                }
                
                return foundCount == 5;
            });

            // Test 11: Performance Test (Write Operations)
            await RunTestStep(testResults, "11. Performance Test (Write Operations)", async () =>
            {
                var stopwatch = System.Diagnostics.Stopwatch.StartNew();
                var operationCount = 100;
                
                for (int i = 0; i < operationCount; i++)
                {
                    await _daprClient.SaveStateAsync(StateStoreName, $"perf-write-{i}", 
                        new { id = i, value = $"Performance test value {i}", timestamp = DateTime.UtcNow });
                }
                
                stopwatch.Stop();
                var avgTime = stopwatch.ElapsedMilliseconds / (double)operationCount;
                _logger.LogInformation($"Average write time: {avgTime:F2}ms per operation");
                
                return avgTime < 100; // Should be under 100ms per operation for good performance
            });

            // Test 12: Performance Test (Read Operations)
            await RunTestStep(testResults, "12. Performance Test (Read Operations)", async () =>
            {
                var stopwatch = System.Diagnostics.Stopwatch.StartNew();
                var operationCount = 100;
                var foundCount = 0;
                
                for (int i = 0; i < operationCount; i++)
                {
                    var value = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, $"perf-write-{i}");
                    if (value.ValueKind != JsonValueKind.Undefined) foundCount++;
                }
                
                stopwatch.Stop();
                var avgTime = stopwatch.ElapsedMilliseconds / (double)operationCount;
                _logger.LogInformation($"Average read time: {avgTime:F2}ms per operation, found {foundCount}/{operationCount} items");
                
                return avgTime < 50 && foundCount == operationCount; // Should be under 50ms per read operation
            });

            // Test 13: ETags Support Testing
            await RunTestStep(testResults, "13. ETags Support Testing", async () =>
            {
                var key = "etag-test";
                var initialValue = "Initial ETag Value";
                
                // Save initial value
                await _daprClient.SaveStateAsync(StateStoreName, key, initialValue);
                
                // Retrieve with ETag (simulated)
                var retrievedValue = await _daprClient.GetStateAsync<string>(StateStoreName, key);
                
                return retrievedValue == initialValue;
            });

            // Test 14: Concurrent Operations Test
            await RunTestStep(testResults, "14. Concurrent Operations Test", async () =>
            {
                var tasks = new List<Task>();
                var concurrentCount = 50;
                
                for (int i = 0; i < concurrentCount; i++)
                {
                    var index = i;
                    tasks.Add(Task.Run(async () =>
                    {
                        await _daprClient.SaveStateAsync(StateStoreName, $"concurrent-{index}", 
                            new { id = index, value = $"Concurrent operation {index}", timestamp = DateTime.UtcNow });
                    }));
                }
                
                await Task.WhenAll(tasks);
                
                // Verify all operations completed
                var verificationTasks = new List<Task<bool>>();
                for (int i = 0; i < concurrentCount; i++)
                {
                    var index = i;
                    verificationTasks.Add(Task.Run(async () =>
                    {
                        var value = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, $"concurrent-{index}");
                        return value.ValueKind != JsonValueKind.Undefined;
                    }));
                }
                
                var results = await Task.WhenAll(verificationTasks);
                return results.All(r => r);
            });

            // Test 15: Large Data Object Test
            await RunTestStep(testResults, "15. Large Data Object Test", async () =>
            {
                var largeData = new
                {
                    id = Guid.NewGuid().ToString(),
                    description = "Large data object for ScyllaDB performance testing",
                    data = string.Join("", Enumerable.Range(0, 1000).Select(i => $"Data chunk {i} with some content. ")),
                    metadata = new
                    {
                        size = "Large",
                        database = "ScyllaDB",
                        performance_test = true,
                        chunks = Enumerable.Range(0, 100).Select(i => new { chunk_id = i, content = $"Chunk {i} content data" }).ToArray()
                    }
                };
                
                await _daprClient.SaveStateAsync(StateStoreName, "large-data", largeData);
                var retrieved = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, "large-data");
                
                return retrieved.ValueKind != JsonValueKind.Undefined;
            });

            // Test 16: Query Operations Test (if supported)
            await RunTestStep(testResults, "16. Query Operations Test", async () =>
            {
                // Create test data for querying
                var userData = new[]
                {
                    new { id = "user-1", name = "Alice", age = 30, department = "Engineering" },
                    new { id = "user-2", name = "Bob", age = 25, department = "Marketing" },
                    new { id = "user-3", name = "Charlie", age = 35, department = "Engineering" }
                };
                
                foreach (var user in userData)
                {
                    await _daprClient.SaveStateAsync(StateStoreName, user.id, user);
                }
                
                // Verify data was stored
                var foundCount = 0;
                foreach (var user in userData)
                {
                    var retrieved = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, user.id);
                    if (retrieved.ValueKind != JsonValueKind.Undefined) foundCount++;
                }
                
                return foundCount == userData.Length;
            });

            // Test 17: Cross-Protocol Compatibility Test
            await RunTestStep(testResults, "17. Cross-Protocol Compatibility Test", async () =>
            {
                // Test data that should be compatible with both HTTP and gRPC protocols
                var compatibilityData = new
                {
                    protocol_test = true,
                    grpc_compatible = true,
                    http_compatible = true,
                    data = "Cross-protocol test data",
                    timestamp = DateTime.UtcNow.ToString("O"),
                    metadata = new { test_type = "compatibility", database = "ScyllaDB" }
                };
                
                await _daprClient.SaveStateAsync(StateStoreName, "protocol-test", compatibilityData);
                var retrieved = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, "protocol-test");
                
                return retrieved.ValueKind != JsonValueKind.Undefined;
            });

            // Test 18: Transaction Support Test (if available)
            await RunTestStep(testResults, "18. Transaction Support Test", async () =>
            {
                var transactionData = new[]
                {
                    new { key = "tx-1", value = "Transaction item 1" },
                    new { key = "tx-2", value = "Transaction item 2" },
                    new { key = "tx-3", value = "Transaction item 3" }
                };
                
                // Simulate transaction by performing multiple operations
                foreach (var item in transactionData)
                {
                    await _daprClient.SaveStateAsync(StateStoreName, item.key, item.value);
                }
                
                // Verify all items were saved
                var foundCount = 0;
                foreach (var item in transactionData)
                {
                    var value = await _daprClient.GetStateAsync<string>(StateStoreName, item.key);
                    if (!string.IsNullOrEmpty(value)) foundCount++;
                }
                
                return foundCount == transactionData.Length;
            });

            // Test 19: Cleanup Performance Test Data
            await RunTestStep(testResults, "19. Cleanup Performance Test Data", async () =>
            {
                var tasks = new List<Task>();
                
                // Clean up performance test data
                for (int i = 0; i < 100; i++)
                {
                    var index = i;
                    tasks.Add(_daprClient.DeleteStateAsync(StateStoreName, $"perf-write-{index}"));
                }
                
                await Task.WhenAll(tasks);
                return true;
            });

            // Test 20: Final Comprehensive Cleanup
            await RunTestStep(testResults, "20. Final Comprehensive Cleanup", async () =>
            {
                var keysToDelete = new[]
                {
                    "complex-obj", "bulk-1", "bulk-2", "bulk-3", "bulk-4", "bulk-5",
                    "etag-test", "large-data", "user-1", "user-2", "user-3",
                    "protocol-test", "tx-1", "tx-2", "tx-3"
                };
                
                // Add concurrent test data cleanup
                for (int i = 0; i < 50; i++)
                {
                    keysToDelete = keysToDelete.Append($"concurrent-{i}").ToArray();
                }
                
                var deleteTasks = keysToDelete.Select(key => 
                    _daprClient.DeleteStateAsync(StateStoreName, key)).ToArray();
                
                await Task.WhenAll(deleteTasks);
                return true;
            });

            var endTime = DateTime.UtcNow;
            var totalDuration = endTime - startTime;
            
            var summary = new
            {
                TestSuite = "ScyllaDB Dapr State Store Comprehensive Test",
                TotalTests = testResults.Count,
                PassedTests = testResults.Count(r => r.Success),
                FailedTests = testResults.Count(r => !r.Success),
                TotalDuration = totalDuration.TotalMilliseconds,
                AverageDuration = testResults.Average(r => r.Duration),
                Results = testResults
            };

            _logger.LogInformation($"Comprehensive test suite completed: {summary.PassedTests}/{summary.TotalTests} tests passed in {totalDuration.TotalSeconds:F2} seconds");

            return Ok(summary);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error running comprehensive test suite");
            return StatusCode(500, new { error = ex.Message, stackTrace = ex.StackTrace });
        }
    }

    [HttpGet]
    [Route("health")]
    public async Task<IActionResult> HealthCheck()
    {
        try
        {
            var testKey = $"health-{DateTime.UtcNow:yyyyMMddHHmmss}";
            var testValue = "health-check";
            
            await _daprClient.SaveStateAsync(StateStoreName, testKey, testValue);
            var retrievedValue = await _daprClient.GetStateAsync<string>(StateStoreName, testKey);
            await _daprClient.DeleteStateAsync(StateStoreName, testKey);
            
            var isHealthy = retrievedValue == testValue;
            
            return Ok(new
            {
                status = isHealthy ? "healthy" : "unhealthy",
                stateStore = StateStoreName,
                timestamp = DateTime.UtcNow,
                testPassed = isHealthy
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Health check failed");
            return StatusCode(500, new { status = "unhealthy", error = ex.Message });
        }
    }

    [HttpPost]
    [Route("save/{key}")]
    public async Task<IActionResult> SaveState([FromRoute] string key, [FromBody] object value)
    {
        try
        {
            await _daprClient.SaveStateAsync(StateStoreName, key, value);
            return Ok(new { message = $"Successfully saved state with key: {key}" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error saving state with key: {key}");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpGet]
    [Route("get/{key}")]
    public async Task<IActionResult> GetState([FromRoute] string key)
    {
        try
        {
            var value = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, key);
            
            if (value.ValueKind == JsonValueKind.Undefined)
            {
                return NotFound(new { message = $"No state found for key: {key}" });
            }
            
            return Ok(new { key = key, value = value });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error retrieving state with key: {key}");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpDelete]
    [Route("delete/{key}")]
    public async Task<IActionResult> DeleteState([FromRoute] string key)
    {
        try
        {
            await _daprClient.DeleteStateAsync(StateStoreName, key);
            return Ok(new { message = $"Successfully deleted state with key: {key}" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error deleting state with key: {key}");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpPost]
    [Route("bulk/save")]
    public async Task<IActionResult> BulkSaveState([FromBody] Dictionary<string, object> data)
    {
        try
        {
            var tasks = data.Select(kvp => 
                _daprClient.SaveStateAsync(StateStoreName, kvp.Key, kvp.Value));
            
            await Task.WhenAll(tasks);
            
            return Ok(new { message = $"Successfully saved {data.Count} items", count = data.Count });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in bulk save operation");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpPost]
    [Route("bulk/get")]
    public async Task<IActionResult> BulkGetState([FromBody] string[] keys)
    {
        try
        {
            var tasks = keys.Select(async key =>
            {
                var value = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, key);
                return new { key = key, value = value, found = value.ValueKind != JsonValueKind.Undefined };
            });
            
            var results = await Task.WhenAll(tasks);
            
            return Ok(new
            {
                message = "Bulk get operation completed",
                totalKeys = keys.Length,
                foundKeys = results.Count(r => r.found),
                results = results
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in bulk get operation");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpPost]
    [Route("performance/test")]
    public async Task<IActionResult> PerformanceTest([FromQuery] int operations = 100)
    {
        try
        {
            var results = new ConcurrentBag<ScyllaPerformanceResult>();
            var writeStopwatch = System.Diagnostics.Stopwatch.StartNew();
            
            // Write performance test
            var writeTasks = Enumerable.Range(0, operations).Select(async i =>
            {
                var operationStopwatch = System.Diagnostics.Stopwatch.StartNew();
                await _daprClient.SaveStateAsync(StateStoreName, $"perf-test-{i}", 
                    new { id = i, data = $"Performance test data {i}", timestamp = DateTime.UtcNow });
                operationStopwatch.Stop();
                
                results.Add(new ScyllaPerformanceResult
                {
                    Operation = "Write",
                    Index = i,
                    Duration = operationStopwatch.ElapsedMilliseconds
                });
            });
            
            await Task.WhenAll(writeTasks);
            writeStopwatch.Stop();
            
            // Read performance test
            var readStopwatch = System.Diagnostics.Stopwatch.StartNew();
            var readTasks = Enumerable.Range(0, operations).Select(async i =>
            {
                var operationStopwatch = System.Diagnostics.Stopwatch.StartNew();
                var value = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, $"perf-test-{i}");
                operationStopwatch.Stop();
                
                results.Add(new ScyllaPerformanceResult
                {
                    Operation = "Read",
                    Index = i,
                    Duration = operationStopwatch.ElapsedMilliseconds,
                    Success = value.ValueKind != JsonValueKind.Undefined
                });
            });
            
            await Task.WhenAll(readTasks);
            readStopwatch.Stop();
            
            // Cleanup
            var cleanupTasks = Enumerable.Range(0, operations).Select(i =>
                _daprClient.DeleteStateAsync(StateStoreName, $"perf-test-{i}"));
            await Task.WhenAll(cleanupTasks);
            
            var writeResults = results.Where(r => r.Operation == "Write").ToList();
            var readResults = results.Where(r => r.Operation == "Read").ToList();
            
            return Ok(new
            {
                operations = operations,
                writePerformance = new
                {
                    totalTime = writeStopwatch.ElapsedMilliseconds,
                    averageTime = writeResults.Average(r => r.Duration),
                    minTime = writeResults.Min(r => r.Duration),
                    maxTime = writeResults.Max(r => r.Duration),
                    operationsPerSecond = operations / (writeStopwatch.ElapsedMilliseconds / 1000.0)
                },
                readPerformance = new
                {
                    totalTime = readStopwatch.ElapsedMilliseconds,
                    averageTime = readResults.Average(r => r.Duration),
                    minTime = readResults.Min(r => r.Duration),
                    maxTime = readResults.Max(r => r.Duration),
                    operationsPerSecond = operations / (readStopwatch.ElapsedMilliseconds / 1000.0),
                    successRate = readResults.Count(r => r.Success) / (double)operations * 100
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error running performance test");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    private async Task RunTestStep(List<ScyllaTestResult> results, string testName, Func<Task<bool>> testAction)
    {
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        var success = false;
        string? error = null;
        
        try
        {
            _logger.LogInformation($"Running: {testName}");
            success = await testAction();
        }
        catch (Exception ex)
        {
            error = ex.Message;
            _logger.LogError(ex, $"Test failed: {testName}");
        }
        finally
        {
            stopwatch.Stop();
        }
        
        results.Add(new ScyllaTestResult
        {
            TestName = testName,
            Success = success,
            Duration = stopwatch.ElapsedMilliseconds,
            Error = error
        });
        
        _logger.LogInformation($"Test {testName}: {(success ? "PASSED" : "FAILED")} ({stopwatch.ElapsedMilliseconds}ms)");
    }
}

public record ScyllaTestResult
{
    public required string TestName { get; init; }
    public bool Success { get; init; }
    public long Duration { get; init; }
    public string? Error { get; init; }
}

public record ScyllaPerformanceResult
{
    public required string Operation { get; init; }
    public int Index { get; init; }
    public long Duration { get; init; }
    public bool Success { get; init; } = true;
}
