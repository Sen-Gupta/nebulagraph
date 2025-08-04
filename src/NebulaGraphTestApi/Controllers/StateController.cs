using Dapr.Client;
using Microsoft.AspNetCore.Mvc;

namespace NebulaGraphTestApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StateController : ControllerBase
{
    private readonly DaprClient _daprClient;
    private readonly ILogger<StateController> _logger;
    private const string MainComponentAppId = "nebulagraph-test";
    
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
            _logger.LogInformation("HTTP: Getting value for key: {Key} via service invocation", key);
            var response = await _daprClient.InvokeMethodAsync<object, GetValueResponse>(
                httpMethod: HttpMethod.Get,
                appId: MainComponentAppId,
                methodName: $"api/state/{key}",
                data: null
            );
            if (response == null || !response.Found)
            {
                return NotFound(new { key, found = false, error = response?.Error ?? "Key not found" });
            }
            return Ok(new { key, value = response.Value, found = true });
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
            _logger.LogInformation("HTTP: Setting value for key: {Key} via service invocation", key);
            var response = await _daprClient.InvokeMethodAsync<SetValueRequest, SetValueResponse>(
                httpMethod: HttpMethod.Post,
                appId: MainComponentAppId,
                methodName: $"api/state/{key}",
                data: request
            );
            if (response == null || !response.Success)
            {
                return StatusCode(500, new { key, success = false, error = response?.Error ?? "Unknown error" });
            }
            return Ok(new { key, success = true });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "HTTP: Error setting value for key: {Key}", key);
            return StatusCode(500, new { key, success = false, error = ex.Message });
        }
    }

    [HttpDelete("{key}")]
    public async Task<IActionResult> DeleteValue(string key)
    {
        try
        {
            _logger.LogInformation("HTTP: Deleting value for key: {Key} via service invocation", key);
            var response = await _daprClient.InvokeMethodAsync<object, DeleteValueResponse>(
                httpMethod: HttpMethod.Delete,
                appId: MainComponentAppId,
                methodName: $"api/state/{key}",
                data: null
            );
            if (response == null || !response.Success)
            {
                return StatusCode(500, new { key, success = false, error = response?.Error ?? "Unknown error" });
            }
            return Ok(new { key, success = true });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "HTTP: Error deleting value for key: {Key}", key);
            return StatusCode(500, new { key, success = false, error = ex.Message });
        }
    }

// Response classes should be outside the controller class
public class GetValueResponse
{
    public string? Value { get; set; }
    public bool Found { get; set; }
    public string? Error { get; set; }
}

public class SetValueResponse
{
    public bool Success { get; set; }
    public string? Error { get; set; }
}

public class DeleteValueResponse
{
    public bool Success { get; set; }
    public string? Error { get; set; }
}

public class SetValueRequest
{
    public string Value { get; set; } = string.Empty;
}

public class BulkOperationRequest
{
    public List<BulkOperation> Operations { get; set; } = new();
}

public class BulkOperationResponse
{
    public bool Success { get; set; }
    public int OperationsCount { get; set; }
    public string? Error { get; set; }
}

public class BulkOperation
{
    public string Key { get; set; } = string.Empty;
    public string? Value { get; set; }
    public string Operation { get; set; } = "set"; // "set" or "delete"
}

public class ListKeysResponse
{
    public List<string> Keys { get; set; } = new();
    public string? Prefix { get; set; }
    public string? Error { get; set; }
}
public class GetValueResponse
{
    public string? Value { get; set; }
    public bool Found { get; set; }
    public string? Error { get; set; }

public class SetValueResponse
{
    public bool Success { get; set; }
    public string? Error { get; set; }
}

public class DeleteValueResponse
{
    public bool Success { get; set; }
    public string? Error { get; set; }
}
    }

    [HttpGet]
    [Route("list")]
    public async Task<IActionResult> ListKeys([FromQuery] string? prefix = null, [FromQuery] int limit = 10)
    {
        try
        {
            _logger.LogInformation("HTTP: Listing keys with prefix: {Prefix}, limit: {Limit} via service invocation", prefix, limit);
            var queryParams = string.IsNullOrEmpty(prefix) ? $"limit={limit}" : $"prefix={prefix}&limit={limit}";
            var methodName = $"api/state/list?{queryParams}";
            var response = await _daprClient.InvokeMethodAsync<object, ListKeysResponse>(
                httpMethod: HttpMethod.Get,
                appId: MainComponentAppId,
                methodName: methodName,
                data: null
            );
            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "HTTP: Error listing keys with prefix: {Prefix}", prefix);
            return StatusCode(500, new { keys = new string[0], error = ex.Message });
        }
    }

    [HttpPost]
    [Route("bulk")]
    public async Task<IActionResult> BulkOperations([FromBody] BulkOperationRequest request)
    {
        try
        {
            _logger.LogInformation("HTTP: Performing bulk operations: {Count} items via service invocation", request.Operations.Count);
            var response = await _daprClient.InvokeMethodAsync<BulkOperationRequest, BulkOperationResponse>(
                httpMethod: HttpMethod.Post,
                appId: MainComponentAppId,
                methodName: "api/state/bulk",
                data: request
            );
            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "HTTP: Error performing bulk operations");
            return StatusCode(500, new { success = false, error = ex.Message });
        }
    }
    // End of StateController

public class SetValueRequest
{
    public string Value { get; set; } = string.Empty;
}

public class BulkOperationRequest
{
    public List<BulkOperation> Operations { get; set; } = new();
}

public class BulkOperationResponse
{
    public bool Success { get; set; }
    public int OperationsCount { get; set; }
    public string? Error { get; set; }
}

public class BulkOperation
{
    public string Key { get; set; } = string.Empty;
    public string? Value { get; set; }
    public string Operation { get; set; } = "set"; // "set" or "delete"
}

public class ListKeysResponse
{
    public List<string> Keys { get; set; } = new();
    public string? Prefix { get; set; }
    public string? Error { get; set; }
}

}
