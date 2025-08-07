using Dapr.Client;
using Microsoft.AspNetCore.Mvc;

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
