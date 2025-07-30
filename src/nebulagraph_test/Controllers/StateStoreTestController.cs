using Microsoft.AspNetCore.Mvc;
using Dapr.Client;
using System.Text.Json;

namespace NebulaGraphTest.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StateStoreTestController : ControllerBase
{
    private readonly DaprClient _daprClient;
    private readonly ILogger<StateStoreTestController> _logger;
    private const string StateStoreName = "nebulagraph-state";

    public StateStoreTestController(DaprClient daprClient, ILogger<StateStoreTestController> logger)
    {
        _daprClient = daprClient;
        _logger = logger;
    }

    /// <summary>
    /// Test saving state using Dapr SDK (gRPC)
    /// </summary>
    [HttpPost("save-grpc/{key}")]
    public async Task<IActionResult> SaveStateGrpc(string key, [FromBody] object value)
    {
        try
        {
            _logger.LogInformation("Saving state via gRPC: Key={Key}, Value={Value}", key, value);
            
            await _daprClient.SaveStateAsync(StateStoreName, key, value);
            
            return Ok(new { 
                success = true, 
                message = $"State saved successfully via gRPC",
                key = key,
                method = "gRPC"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving state via gRPC");
            return StatusCode(500, new { 
                success = false, 
                error = ex.Message,
                method = "gRPC"
            });
        }
    }

    /// <summary>
    /// Test retrieving state using Dapr SDK (gRPC)
    /// </summary>
    [HttpGet("get-grpc/{key}")]
    public async Task<IActionResult> GetStateGrpc(string key)
    {
        try
        {
            _logger.LogInformation("Getting state via gRPC: Key={Key}", key);
            
            var result = await _daprClient.GetStateAsync<object>(StateStoreName, key);
            
            return Ok(new { 
                success = true, 
                key = key,
                value = result,
                method = "gRPC"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting state via gRPC");
            return StatusCode(500, new { 
                success = false, 
                error = ex.Message,
                method = "gRPC"
            });
        }
    }

    /// <summary>
    /// Test deleting state using Dapr SDK (gRPC)
    /// </summary>
    [HttpDelete("delete-grpc/{key}")]
    public async Task<IActionResult> DeleteStateGrpc(string key)
    {
        try
        {
            _logger.LogInformation("Deleting state via gRPC: Key={Key}", key);
            
            await _daprClient.DeleteStateAsync(StateStoreName, key);
            
            return Ok(new { 
                success = true, 
                message = $"State deleted successfully via gRPC",
                key = key,
                method = "gRPC"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting state via gRPC");
            return StatusCode(500, new { 
                success = false, 
                error = ex.Message,
                method = "gRPC"
            });
        }
    }

    /// <summary>
    /// Test bulk state operations using Dapr SDK (gRPC)
    /// </summary>
    [HttpPost("bulk-save-grpc")]
    public async Task<IActionResult> BulkSaveStateGrpc([FromBody] Dictionary<string, object> states)
    {
        try
        {
            _logger.LogInformation("Bulk saving {Count} states via gRPC", states.Count);
            
            var stateItems = states.Select(kvp => new SaveStateItem<object>(kvp.Key, kvp.Value, "")).ToList();
            await _daprClient.SaveBulkStateAsync(StateStoreName, stateItems);
            
            return Ok(new { 
                success = true, 
                message = $"Bulk saved {states.Count} states successfully via gRPC",
                count = states.Count,
                method = "gRPC"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error bulk saving states via gRPC");
            return StatusCode(500, new { 
                success = false, 
                error = ex.Message,
                method = "gRPC"
            });
        }
    }

    /// <summary>
    /// Test bulk state retrieval using Dapr SDK (gRPC)
    /// </summary>
    [HttpPost("bulk-get-grpc")]
    public async Task<IActionResult> BulkGetStateGrpc([FromBody] string[] keys)
    {
        try
        {
            _logger.LogInformation("Bulk getting {Count} states via gRPC", keys.Length);
            
            var results = await _daprClient.GetBulkStateAsync(StateStoreName, keys, parallelism: 5);
            
            var response = results.ToDictionary(
                item => item.Key, 
                item => item.Value
            );
            
            return Ok(new { 
                success = true, 
                count = results.Count(),
                states = response,
                method = "gRPC"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error bulk getting states via gRPC");
            return StatusCode(500, new { 
                success = false, 
                error = ex.Message,
                method = "gRPC"
            });
        }
    }
}
