using Dapr.Client;
using Microsoft.AspNetCore.Mvc;

namespace NebulaGraphTestApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StateController : ControllerBase
{
    private readonly DaprClient _daprClient;
    private readonly ILogger<StateController> _logger;
    private const string StoreName = "nebulagraph-store";

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
            _logger.LogInformation("Getting value for key: {Key}", key);
            
            var value = await _daprClient.GetStateAsync<string>(StoreName, key);
            
            if (value == null)
            {
                return NotFound(new { key, found = false, error = "Key not found" });
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
            _logger.LogInformation("Setting value for key: {Key}", key);
            
            await _daprClient.SaveStateAsync(StoreName, key, request.Value);
            
            return Ok(new { key, success = true });
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
            _logger.LogInformation("Deleting value for key: {Key}", key);
            
            await _daprClient.DeleteStateAsync(StoreName, key);
            
            return Ok(new { key, success = true });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting value for key: {Key}", key);
            return StatusCode(500, new { key, success = false, error = ex.Message });
        }
    }

    [HttpGet]
    [Route("list")]
    public async Task<IActionResult> ListKeys([FromQuery] string? prefix = null, [FromQuery] int limit = 10)
    {
        try
        {
            _logger.LogInformation("Listing keys with prefix: {Prefix}, limit: {Limit}", prefix, limit);
            
            // Note: This is a basic implementation as Dapr doesn't have a built-in list operation
            // In a real scenario, you might need to maintain a separate index
            var keys = new List<string>();
            
            // For demonstration, we'll return some test keys
            // In a real implementation, you'd query your state store directly
            return Ok(new { keys, prefix });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error listing keys with prefix: {Prefix}", prefix);
            return StatusCode(500, new { keys = new string[0], error = ex.Message });
        }
    }

    [HttpPost]
    [Route("bulk")]
    public async Task<IActionResult> BulkOperations([FromBody] BulkOperationRequest request)
    {
        try
        {
            _logger.LogInformation("Performing bulk operations: {Count} items", request.Operations.Count);
            
            var operations = request.Operations.Select(op =>
            {
                return op.Operation.ToLower() switch
                {
                    "set" => new StateTransactionRequest(op.Key, System.Text.Encoding.UTF8.GetBytes(op.Value ?? ""), StateOperationType.Upsert),
                    "delete" => new StateTransactionRequest(op.Key, null, StateOperationType.Delete),
                    _ => throw new ArgumentException($"Unknown operation: {op.Operation}")
                };
            }).ToList();

            await _daprClient.ExecuteStateTransactionAsync(StoreName, operations);
            
            return Ok(new { success = true, operationsCount = operations.Count });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error performing bulk operations");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }
}

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
