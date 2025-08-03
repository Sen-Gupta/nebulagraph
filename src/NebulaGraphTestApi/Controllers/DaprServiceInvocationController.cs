using Dapr.Client;
using Microsoft.AspNetCore.Mvc;

namespace NebulaGraphTestApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DaprServiceInvocationController : ControllerBase
{
    private readonly ILogger<DaprServiceInvocationController> _logger;
    private readonly DaprClient _daprClient;

    public DaprServiceInvocationController(ILogger<DaprServiceInvocationController> logger, DaprClient daprClient)
    {
        _logger = logger;
        _daprClient = daprClient;
    }

    

    /// <summary>
    /// Test using the proper DaprClient with gRPC endpoint configuration
    /// </summary>
    [HttpGet("grpc-client/get/{key}")]
    public async Task<IActionResult> TestWithProperGrpcClient(string key)
    {
        try
        {
            _logger.LogInformation("Testing with properly configured DaprClient gRPC endpoint for key: {Key}", key);

            // Create a DaprClient specifically configured for gRPC endpoint
            using var daprClient = new DaprClientBuilder()
                .UseGrpcEndpoint("http://localhost:50000") // NebulaGraph component Dapr gRPC port
                .Build();

            using (daprClient)
            {
                // Test state store operation via gRPC-configured client
                var result = await daprClient.GetStateAsync<string>("nebulagraph-state", key);

                return Ok(new
                {
                    method = "DaprClient.UseGrpcEndpoint.GetStateAsync",
                    grpcEndpoint = "http://localhost:50000",
                    storeName = "nebulagraph-state",
                    key = key,
                    value = result,
                    found = !string.IsNullOrEmpty(result),
                    success = true
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error with gRPC-configured DaprClient for key: {Key}", key);
            return StatusCode(500, new
            {
                method = "DaprClient.UseGrpcEndpoint.GetStateAsync",
                grpcEndpoint = "http://localhost:50000",
                key = key,
                success = false,
                error = ex.Message
            });
        }
    }

    /// <summary>
    /// Test saving state with gRPC-configured DaprClient
    /// </summary>
    [HttpPost("grpc-client/set/{key}")]
    public async Task<IActionResult> TestSaveWithGrpcClient(string key, [FromBody] SetValueTestRequest request)
    {
        try
        {
            _logger.LogInformation("Testing SaveState with gRPC-configured DaprClient for key: {Key}", key);

            var daprClientBuilder = new DaprClientBuilder()
                .UseGrpcEndpoint("http://localhost:50000")
                .Build();

            using (daprClientBuilder)
            {
                await daprClientBuilder.SaveStateAsync("nebulagraph-state", key, request.Value);

                return Ok(new
                {
                    method = "DaprClient.UseGrpcEndpoint.SaveStateAsync",
                    grpcEndpoint = "http://localhost:50000",
                    storeName = "nebulagraph-state",
                    key = key,
                    value = request.Value,
                    success = true
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving with gRPC-configured DaprClient for key: {Key}", key);
            return StatusCode(500, new
            {
                method = "DaprClient.UseGrpcEndpoint.SaveStateAsync",
                grpcEndpoint = "http://localhost:50000",
                key = key,
                success = false,
                error = ex.Message
            });
        }
    }

    
    /// <summary>
    /// Get service invocation info
    /// </summary>
    [HttpGet("info")]
    public IActionResult GetServiceInvocationInfo()
    {
        return Ok(new
        {
            service = "Dapr Service Invocation Test Controller",
            description = "Tests different patterns for Dapr gRPC communication",
            availableOperations = new[]
            {
                "GET /api/daprserviceinvocation/invoke-self/get/{key} - Test service invocation to self",
                "GET /api/daprserviceinvocation/grpc-client/get/{key} - Test with gRPC-configured DaprClient",
                "POST /api/daprserviceinvocation/grpc-client/set/{key} - Test SaveState with gRPC client",
                "POST /api/daprserviceinvocation/compare-approaches - Compare HTTP vs gRPC approaches"
            },
            endpoints = new
            {
                defaultDaprHttp = "http://localhost:3502",
                daprGrpc = "http://localhost:50002",
                appId = "test-api"
            },
            timestamp = DateTime.UtcNow
        });
    }
}
