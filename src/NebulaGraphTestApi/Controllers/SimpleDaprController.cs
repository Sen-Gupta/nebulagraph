using Dapr.Client;
using Microsoft.AspNetCore.Mvc;
using NebulaGraphTestApi.Protos;

namespace NebulaGraphTestApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SimpleDaprController : ControllerBase
{
    private readonly ILogger<SimpleDaprController> _logger;

    public SimpleDaprController(ILogger<SimpleDaprController> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Set state using Dapr gRPC service invocation
    /// </summary>
    [HttpPost("set/{key}")]
    public async Task<IActionResult> SetState(string key, [FromBody] SetStateRequest request)
    {
        try
        {
            _logger.LogInformation("Setting state via Dapr gRPC: {Key} = {Value}", key, request.Value);

            // The gRPC Dapr sidecar address (NebulaGraph component port 50000)
            using var daprClient = new DaprClientBuilder()
                .UseGrpcEndpoint("http://localhost:50000") // Set NebulaGraph component Dapr gRPC endpoint
                .Build();

            var grpcRequest = new Protos.SetValueRequest 
            { 
                Key = key, 
                Value = request.Value 
            };

            // Calls the remote method "SetValue" on the other app via Dapr service invocation
            var reply = await daprClient.InvokeMethodGrpcAsync<Protos.SetValueRequest, Protos.SetValueResponse>(
                "test-api",      // remote app ID registered with Dapr
                "SetValue",      // gRPC service method name
                grpcRequest
            );

            return Ok(new
            {
                message = reply.Success ? "State set successfully via Dapr gRPC!" : "Failed to set state",
                key = key,
                value = request.Value,
                success = reply.Success,
                error = reply.Error
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error setting state via Dapr gRPC for key: {Key}", key);
            return StatusCode(500, new
            {
                message = "Failed to set state via Dapr gRPC",
                key = key,
                error = ex.Message,
                success = false
            });
        }
    }

    /// <summary>
    /// Get state using Dapr gRPC service invocation
    /// </summary>
    [HttpGet("get/{key}")]
    public async Task<IActionResult> GetState(string key)
    {
        try
        {
            _logger.LogInformation("Getting state via Dapr gRPC for key: {Key}", key);

            // The gRPC Dapr sidecar address (NebulaGraph component port 50000)
            using var daprClient = new DaprClientBuilder()
                .UseGrpcEndpoint("http://localhost:50000") // Set NebulaGraph component Dapr gRPC endpoint
                .Build();

            var grpcRequest = new Protos.GetValueRequest { Key = key };

            // Calls the remote method "GetValue" on the other app via Dapr service invocation
            var reply = await daprClient.InvokeMethodGrpcAsync<Protos.GetValueRequest, Protos.GetValueResponse>(
                "test-api",      // remote app ID registered with Dapr
                "GetValue",      // gRPC service method name
                grpcRequest
            );

            return Ok(new
            {
                message = reply.Found ? "State retrieved successfully via Dapr gRPC!" : "State not found",
                key = key,
                value = reply.Value,
                found = reply.Found,
                success = true,
                error = reply.Error
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting state via Dapr gRPC for key: {Key}", key);
            return StatusCode(500, new
            {
                message = "Failed to get state via Dapr gRPC",
                key = key,
                error = ex.Message,
                success = false
            });
        }
    }

    /// <summary>
    /// Simple test endpoint to verify controller is working
    /// </summary>
    [HttpGet("test")]
    public IActionResult Test()
    {
        return Ok(new
        {
            message = "SimpleDaprController is working!",
            timestamp = DateTime.UtcNow,
            controller = "SimpleDaprController"
        });
    }

    /// <summary>
    /// Get info about this Dapr gRPC controller
    /// </summary>
    [HttpGet("info")]
    public IActionResult GetInfo()
    {
        return Ok(new
        {
            service = "Simple Dapr gRPC Controller",
            description = "Get and set state operations using Dapr gRPC service invocation",
            appId = "test-api",
            storeName = "nebulagraph-state", // The state store used by our gRPC service
            daprEndpoint = "http://localhost:50000",
            grpcMethods = new[]
            {
                "SetValue - Set state value via gRPC (uses nebulagraph-state store)",
                "GetValue - Get state value via gRPC (uses nebulagraph-state store)"
            },
            availableOperations = new[]
            {
                "POST /api/simpledapr/set/{key} - Set state value via Dapr gRPC",
                "GET /api/simpledapr/get/{key} - Get state value via Dapr gRPC"
            },
            note = "This controller calls our own gRPC service methods via Dapr service invocation. The gRPC service internally uses the 'nebulagraph-state' store.",
            timestamp = DateTime.UtcNow
        });
    }

    /// <summary>
    /// Direct state operation for comparison (bypasses gRPC service)
    /// </summary>
    [HttpPost("direct-set/{key}")]
    public async Task<IActionResult> DirectSetState(string key, [FromBody] SetStateRequest request)
    {
        try
        {
            _logger.LogInformation("Direct state set: {Key} = {Value}", key, request.Value);

            // Direct Dapr state API call (not via gRPC service)
            using var daprClient = new DaprClientBuilder()
                .UseGrpcEndpoint("http://localhost:50000")
                .Build();

            await daprClient.SaveStateAsync("nebulagraph-state", key, request.Value);
            
            return Ok(new
            {
                message = "State set directly via Dapr state API!",
                storeName = "nebulagraph-state",
                key = key,
                value = request.Value,
                success = true,
                method = "Direct Dapr State API"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in direct state set for key: {Key}", key);
            return StatusCode(500, new
            {
                message = "Failed to set state directly",
                key = key,
                error = ex.Message,
                success = false
            });
        }
    }
}

public class SetStateRequest
{
    public string Value { get; set; } = string.Empty;
}
