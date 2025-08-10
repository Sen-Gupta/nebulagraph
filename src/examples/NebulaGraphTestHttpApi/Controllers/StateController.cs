using Dapr.Client;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace NebulaGraphTestHttpApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StateController : ControllerBase
{
    private readonly DaprClient _daprClient;
    private readonly ILogger<StateController> _logger;
    private const string StateStoreName = "nebulagraph-state";
    
    public StateController(DaprClient daprClient, ILogger<StateController> logger)
    {
        _daprClient = daprClient;
        _logger = logger;
    }

    #region Basic CRUD Operations

    [HttpGet("{key}")]
    public async Task<IActionResult> GetValue(string key)
    {
        try
        {
            _logger.LogInformation("Getting value for key: {Key} from NebulaGraph state store", key);
            var value = await _daprClient.GetStateAsync<string>(StateStoreName, key);
            
            if (string.IsNullOrEmpty(value))
            {
                return NotFound(new { key, found = false, message = "Key not found" });
            }
            
            return Ok(new { key, value, found = true });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting value for key: {Key}", key);
            return StatusCode(500, new { key, found = false, error = ex.Message });
        }
    }

    [HttpPost("{key}")]
    public async Task<IActionResult> SetValue(string key, [FromBody] SetValueRequest request)
    {
        try
        {
            _logger.LogInformation("Setting value for key: {Key} in NebulaGraph state store", key);
            await _daprClient.SaveStateAsync(StateStoreName, key, request.Value);
            
            return Ok(new { key, success = true, message = "Value saved successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error setting value for key: {Key}", key);
            return StatusCode(500, new { key, success = false, error = ex.Message });
        }
    }

    [HttpDelete("{key}")]
    public async Task<IActionResult> DeleteValue(string key)
    {
        try
        {
            _logger.LogInformation("Deleting value for key: {Key} from NebulaGraph state store", key);
            await _daprClient.DeleteStateAsync(StateStoreName, key);
            
            return Ok(new { key, success = true, message = "Value deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting value for key: {Key}", key);
            return StatusCode(500, new { key, success = false, error = ex.Message });
        }
    }

    #endregion

    #region JSON Object Operations

    [HttpPost("{key}/json")]
    public async Task<IActionResult> SetJsonValue(string key, [FromBody] JsonElement jsonValue)
    {
        try
        {
            _logger.LogInformation("Setting JSON value for key: {Key} in NebulaGraph state store", key);
            await _daprClient.SaveStateAsync(StateStoreName, key, jsonValue);
            
            return Ok(new { key, success = true, message = "JSON value saved successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error setting JSON value for key: {Key}", key);
            return StatusCode(500, new { key, success = false, error = ex.Message });
        }
    }

    [HttpGet("{key}/json")]
    public async Task<IActionResult> GetJsonValue(string key)
    {
        try
        {
            _logger.LogInformation("Getting JSON value for key: {Key} from NebulaGraph state store", key);
            var value = await _daprClient.GetStateAsync<JsonElement>(StateStoreName, key);
            
            if (value.ValueKind == JsonValueKind.Undefined)
            {
                return NotFound(new { key, found = false, message = "Key not found" });
            }
            
            return Ok(new { key, value, found = true });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting JSON value for key: {Key}", key);
            return StatusCode(500, new { key, found = false, error = ex.Message });
        }
    }

    #endregion

    #region Bulk Operations

    [HttpGet]
    [Route("bulk")]
    public async Task<IActionResult> BulkGetValues([FromQuery] string keys)
    {
        try
        {
            var keyArray = keys.Split(',', StringSplitOptions.RemoveEmptyEntries);
            _logger.LogInformation("Getting bulk values for {Count} keys from NebulaGraph state store", keyArray.Length);
            
            var results = new List<dynamic>();
            foreach (var key in keyArray)
            {
                var value = await _daprClient.GetStateAsync<string>(StateStoreName, key.Trim());
                results.Add(new { 
                    key = key.Trim(), 
                    value = value, 
                    found = !string.IsNullOrEmpty(value) 
                });
            }
            
            return Ok(new { results = results, count = results.Count });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting bulk values");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpPost]
    [Route("bulk")]
    public async Task<IActionResult> BulkOperations([FromBody] BulkOperationRequest request)
    {
        try
        {
            _logger.LogInformation("Performing bulk operations: {Count} items", request.Operations.Count);
            
            var savedCount = 0;
            var deletedCount = 0;
            
            foreach (var operation in request.Operations)
            {
                if (operation.Operation.ToLower() == "set" && operation.Value != null)
                {
                    await _daprClient.SaveStateAsync(StateStoreName, operation.Key, operation.Value);
                    savedCount++;
                }
                else if (operation.Operation.ToLower() == "delete")
                {
                    await _daprClient.DeleteStateAsync(StateStoreName, operation.Key);
                    deletedCount++;
                }
            }
            
            return Ok(new { 
                success = true, 
                operationsCount = request.Operations.Count,
                savedCount = savedCount,
                deletedCount = deletedCount,
                message = "Bulk operations completed successfully" 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error performing bulk operations");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    [HttpPost]
    [Route("bulk/set")]
    public async Task<IActionResult> BulkSetValues([FromBody] BulkSetRequest request)
    {
        try
        {
            _logger.LogInformation("Performing bulk SET operations: {Count} items", request.Items.Count);
            
            var savedCount = 0;
            foreach (var item in request.Items)
            {
                await _daprClient.SaveStateAsync(StateStoreName, item.Key, item.Value);
                savedCount++;
            }
            
            return Ok(new { 
                success = true, 
                savedCount = savedCount,
                message = "Bulk SET operations completed successfully" 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error performing bulk SET operations");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    [HttpPost]
    [Route("bulk/delete")]
    public async Task<IActionResult> BulkDeleteValues([FromBody] BulkDeleteRequest request)
    {
        try
        {
            _logger.LogInformation("Performing bulk DELETE operations: {Count} keys", request.Keys.Count);
            
            var deletedCount = 0;
            foreach (var key in request.Keys)
            {
                await _daprClient.DeleteStateAsync(StateStoreName, key);
                deletedCount++;
            }
            
            return Ok(new { 
                success = true, 
                deletedCount = deletedCount,
                message = "Bulk DELETE operations completed successfully" 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error performing bulk DELETE operations");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    [HttpPost]
    [Route("bulk/verify")]
    public async Task<IActionResult> VerifyBulkOperations([FromBody] VerifyBulkRequest request)
    {
        try
        {
            _logger.LogInformation("Verifying bulk operations for {Count} keys", request.Keys.Count);
            
            var results = new List<VerifyResult>();
            foreach (var key in request.Keys)
            {
                var value = await _daprClient.GetStateAsync<string>(StateStoreName, key);
                results.Add(new VerifyResult
                {
                    Key = key,
                    Found = !string.IsNullOrEmpty(value),
                    Value = value
                });
            }
            
            return Ok(new { 
                success = true, 
                results = results,
                verifiedCount = results.Count,
                foundCount = results.Count(r => r.Found),
                message = "Bulk verification completed successfully" 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error verifying bulk operations");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    #endregion

    #region Query API Operations

    [HttpPost]
    [Route("query")]
    public async Task<IActionResult> QueryData([FromBody] QueryRequest request)
    {
        try
        {
            _logger.LogInformation("Performing query operation with limit: {Limit}", request.Limit);
            
            // For demonstration, we'll query a few known keys
            // In a real implementation, this would use the Dapr Query API
            var keys = new[] { "query-user-001", "query-user-002", "query-product-001", "query-product-002" };
            var results = new List<QueryResult>();
            
            var count = 0;
            foreach (var key in keys)
            {
                if (count >= request.Limit) break;
                
                var value = await _daprClient.GetStateAsync<string>(StateStoreName, key);
                if (!string.IsNullOrEmpty(value))
                {
                    results.Add(new QueryResult
                    {
                        Key = key,
                        Value = value
                    });
                    count++;
                }
            }
            
            return Ok(new { 
                success = true, 
                results = results,
                count = results.Count,
                message = "Query operation completed successfully" 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error performing query operation");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    [HttpGet]
    [Route("query/performance")]
    public async Task<IActionResult> QueryPerformance()
    {
        try
        {
            _logger.LogInformation("Testing query performance");
            var startTime = DateTime.UtcNow;
            
            // Perform a sample query operation
            var testKey = "performance-test-key";
            var testValue = "Performance test value";
            
            await _daprClient.SaveStateAsync(StateStoreName, testKey, testValue);
            var retrievedValue = await _daprClient.GetStateAsync<string>(StateStoreName, testKey);
            await _daprClient.DeleteStateAsync(StateStoreName, testKey);
            
            var endTime = DateTime.UtcNow;
            var duration = (endTime - startTime).TotalMilliseconds;
            
            return Ok(new { 
                success = true, 
                durationMs = duration,
                operationsPerformed = 3,
                message = "Query performance test completed successfully" 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error testing query performance");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    #endregion

    #region Test Suite Endpoints

    [HttpPost]
    [Route("test/comprehensive")]
    public async Task<IActionResult> ComprehensiveTest()
    {
        try
        {
            _logger.LogInformation("Running comprehensive test suite");
            var testResults = new List<TestResult>();
            var startTime = DateTime.UtcNow;
            
            // Test 1: Basic SET operation
            await RunTest(testResults, "Basic SET Operation", async () =>
            {
                await _daprClient.SaveStateAsync(StateStoreName, "test-key-1", "Hello NebulaGraph!");
                return true;
            });
            
            // Test 2: Basic GET operation (String)
            await RunTest(testResults, "Basic GET Operation (String)", async () =>
            {
                var value = await _daprClient.GetStateAsync<string>(StateStoreName, "test-key-1");
                return value == "Hello NebulaGraph!";
            });
            
            // Test 3: JSON SET/GET operation
            await RunTest(testResults, "JSON SET/GET Operation", async () =>
            {
                var jsonObj = new { message = "This is a JSON value", timestamp = "2025-07-30" };
                await _daprClient.SaveStateAsync(StateStoreName, "test-key-2", jsonObj);
                var retrieved = await _daprClient.GetStateAsync<dynamic>(StateStoreName, "test-key-2");
                return retrieved != null;
            });
            
            // Test 4: DELETE operation
            await RunTest(testResults, "DELETE Operation", async () =>
            {
                await _daprClient.DeleteStateAsync(StateStoreName, "test-key-1");
                var value = await _daprClient.GetStateAsync<string>(StateStoreName, "test-key-1");
                return string.IsNullOrEmpty(value);
            });
            
            // Test 5: Bulk operations
            await RunTest(testResults, "Bulk Operations", async () =>
            {
                // Bulk SET
                var bulkData = new Dictionary<string, object>
                {
                    { "bulk-test-1", "Bulk test value 1" },
                    { "bulk-test-2", new { data = "Bulk test value 2", timestamp = DateTime.UtcNow } },
                    { "bulk-test-3", "Bulk test value 3" }
                };
                
                foreach (var kvp in bulkData)
                {
                    await _daprClient.SaveStateAsync(StateStoreName, kvp.Key, kvp.Value);
                }
                
                // Verify bulk SET
                var value1 = await _daprClient.GetStateAsync<string>(StateStoreName, "bulk-test-1");
                var value2 = await _daprClient.GetStateAsync<dynamic>(StateStoreName, "bulk-test-2");
                var value3 = await _daprClient.GetStateAsync<string>(StateStoreName, "bulk-test-3");
                
                return !string.IsNullOrEmpty(value1) && value2 != null && !string.IsNullOrEmpty(value3);
            });
            
            var endTime = DateTime.UtcNow;
            var totalDuration = (endTime - startTime).TotalMilliseconds;
            
            var passedTests = testResults.Count(t => t.Passed);
            var totalTests = testResults.Count;
            
            return Ok(new { 
                success = true,
                totalTests = totalTests,
                passedTests = passedTests,
                failedTests = totalTests - passedTests,
                successRate = (double)passedTests / totalTests * 100,
                totalDurationMs = totalDuration,
                testResults = testResults,
                message = $"Comprehensive test completed: {passedTests}/{totalTests} tests passed"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error running comprehensive test");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }

    private async Task RunTest(List<TestResult> results, string testName, Func<Task<bool>> testFunc)
    {
        var startTime = DateTime.UtcNow;
        try
        {
            var result = await testFunc();
            var endTime = DateTime.UtcNow;
            var duration = (endTime - startTime).TotalMilliseconds;
            
            results.Add(new TestResult
            {
                TestName = testName,
                Passed = result,
                DurationMs = duration,
                Message = result ? "Test passed" : "Test failed"
            });
        }
        catch (Exception ex)
        {
            var endTime = DateTime.UtcNow;
            var duration = (endTime - startTime).TotalMilliseconds;
            
            results.Add(new TestResult
            {
                TestName = testName,
                Passed = false,
                DurationMs = duration,
                Message = $"Test failed with exception: {ex.Message}"
            });
        }
    }

    #endregion

    #region Health Check

    [HttpGet]
    [Route("health")]
    public async Task<IActionResult> HealthCheck()
    {
        try
        {
            _logger.LogInformation("Performing health check on NebulaGraph state store");
            
            // Test basic operations
            var testKey = $"health-check-{DateTime.UtcNow:yyyyMMdd-HHmmss}";
            var testValue = "Health check test value";
            
            // Test SET
            await _daprClient.SaveStateAsync(StateStoreName, testKey, testValue);
            
            // Test GET
            var retrievedValue = await _daprClient.GetStateAsync<string>(StateStoreName, testKey);
            
            // Test DELETE
            await _daprClient.DeleteStateAsync(StateStoreName, testKey);
            
            var isHealthy = retrievedValue == testValue;
            
            return Ok(new { 
                healthy = isHealthy,
                stateStore = StateStoreName,
                message = isHealthy ? "NebulaGraph state store is working correctly" : "State store test failed",
                timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Health check failed");
            return StatusCode(500, new { 
                healthy = false,
                stateStore = StateStoreName,
                error = ex.Message,
                timestamp = DateTime.UtcNow
            });
        }
    }

    #endregion
}

// Request/Response models
public class SetValueRequest
{
    public string Value { get; set; } = string.Empty;
}

public class BulkOperationRequest
{
    public List<BulkOperation> Operations { get; set; } = new();
}

public class BulkOperation
{
    public string Key { get; set; } = string.Empty;
    public string? Value { get; set; }
    public string Operation { get; set; } = "set"; // "set" or "delete"
}

public class BulkSetRequest
{
    public List<BulkSetItem> Items { get; set; } = new();
}

public class BulkSetItem
{
    public string Key { get; set; } = string.Empty;
    public object Value { get; set; } = string.Empty;
}

public class BulkDeleteRequest
{
    public List<string> Keys { get; set; } = new();
}

public class VerifyBulkRequest
{
    public List<string> Keys { get; set; } = new();
}

public class VerifyResult
{
    public string Key { get; set; } = string.Empty;
    public bool Found { get; set; }
    public string? Value { get; set; }
}

public class QueryRequest
{
    public int Limit { get; set; } = 10;
    public string Filter { get; set; } = string.Empty;
}

public class QueryResult
{
    public string Key { get; set; } = string.Empty;
    public string Value { get; set; } = string.Empty;
}

public class TestResult
{
    public string TestName { get; set; } = string.Empty;
    public bool Passed { get; set; }
    public double DurationMs { get; set; }
    public string Message { get; set; } = string.Empty;
}
