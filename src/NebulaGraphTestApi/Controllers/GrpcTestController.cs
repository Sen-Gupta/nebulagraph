using Grpc.Net.Client;
using Microsoft.AspNetCore.Mvc;
using NebulaGraphTestApi.Protos;

namespace NebulaGraphTestApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class GrpcTestController : ControllerBase
{
    private readonly ILogger<GrpcTestController> _logger;
    private readonly IConfiguration _configuration;

    public GrpcTestController(ILogger<GrpcTestController> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    /// <summary>
    /// Test the gRPC GetValue endpoint
    /// </summary>
    [HttpGet("get/{key}")]
    public async Task<IActionResult> TestGetValue(string key)
    {
        try
        {
                        _logger.LogInformation("gRPC: Getting value for key: {Key}", key);
            
            using var channel = GrpcChannel.ForAddress("http://localhost:50000");
            var client = new NebulaGraphService.NebulaGraphServiceClient(channel);

            var request = new Protos.GetValueRequest { Key = key };
            var response = await client.GetValueAsync(request);

            return Ok(new
            {
                method = "gRPC.GetValue",
                key = key,
                value = response.Value,
                found = response.Found,
                error = response.Error,
                success = string.IsNullOrEmpty(response.Error)
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error testing gRPC GetValue for key: {Key}", key);
            return StatusCode(500, new
            {
                method = "gRPC.GetValue",
                key = key,
                success = false,
                error = ex.Message
            });
        }
    }

    /// <summary>
    /// Test the gRPC SetValue endpoint
    /// </summary>
    [HttpPost("set/{key}")]
    public async Task<IActionResult> TestSetValue(string key, [FromBody] SetValueTestRequest request)
    {
        try
        {
            _logger.LogInformation("Testing gRPC SetValue for key: {Key}", key);

            using var channel = GrpcChannel.ForAddress("http://localhost:50000");
            var client = new NebulaGraphService.NebulaGraphServiceClient(channel);

                        var grpcRequest = new Protos.SetValueRequest { Key = key, Value = request.Value };
            var response = await client.SetValueAsync(grpcRequest);

            return Ok(new
            {
                method = "gRPC.SetValue",
                key = key,
                value = request.Value,
                success = response.Success,
                error = response.Error
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error testing gRPC SetValue for key: {Key}", key);
            return StatusCode(500, new
            {
                method = "gRPC.SetValue",
                key = key,
                success = false,
                error = ex.Message
            });
        }
    }

    /// <summary>
    /// Test the gRPC DeleteValue endpoint
    /// </summary>
    [HttpDelete("delete/{key}")]
    public async Task<IActionResult> TestDeleteValue(string key)
    {
        try
        {
            _logger.LogInformation("Testing gRPC DeleteValue for key: {Key}", key);

            using var channel = GrpcChannel.ForAddress("http://localhost:50000");
            var client = new NebulaGraphService.NebulaGraphServiceClient(channel);

            var request = new Protos.DeleteValueRequest { Key = key };
            var response = await client.DeleteValueAsync(request);

            return Ok(new
            {
                method = "gRPC.DeleteValue",
                key = key,
                success = response.Success,
                error = response.Error
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error testing gRPC DeleteValue for key: {Key}", key);
            return StatusCode(500, new
            {
                method = "gRPC.DeleteValue",
                key = key,
                success = false,
                error = ex.Message
            });
        }
    }

    /// <summary>
    /// Test the gRPC ListKeys endpoint
    /// </summary>
    [HttpGet("list")]
    public async Task<IActionResult> TestListKeys([FromQuery] string? prefix = null, [FromQuery] int limit = 10)
    {
        try
        {
            _logger.LogInformation("Testing gRPC ListKeys with prefix: {Prefix}, limit: {Limit}", prefix, limit);

            using var channel = GrpcChannel.ForAddress("http://localhost:50000");
            var client = new NebulaGraphService.NebulaGraphServiceClient(channel);

            var request = new Protos.ListKeysRequest { Prefix = prefix ?? "", Limit = limit };
            var response = await client.ListKeysAsync(request);

            return Ok(new
            {
                method = "gRPC.ListKeys",
                prefix = prefix,
                limit = limit,
                keys = response.Keys.ToArray(),
                count = response.Keys.Count,
                error = response.Error,
                success = string.IsNullOrEmpty(response.Error)
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error testing gRPC ListKeys");
            return StatusCode(500, new
            {
                method = "gRPC.ListKeys",
                success = false,
                error = ex.Message
            });
        }
    }

    /// <summary>
    /// Run a comprehensive gRPC test suite
    /// </summary>
    [HttpPost("comprehensive-test")]
    public async Task<IActionResult> RunComprehensiveTest([FromBody] ComprehensiveTestRequest request)
    {
        var results = new List<object>();
        var testData = request.TestData ?? new()
        {
            { "grpc-test-1", "Hello gRPC World!" },
            { "grpc-test-2", "Testing NebulaGraph via gRPC" },
            { "grpc-test-3", "Comprehensive test data" }
        };

        try
        {
            _logger.LogInformation("Running comprehensive gRPC test with {Count} items", testData.Count);

            using var channel = GrpcChannel.ForAddress("http://localhost:50000");
            var client = new NebulaGraphService.NebulaGraphServiceClient(channel);

            // Test 1: Set values
            foreach (var kvp in testData)
            {
                var setRequest = new Protos.SetValueRequest { Key = kvp.Key, Value = kvp.Value };
                var setResponse = await client.SetValueAsync(setRequest);
                
                results.Add(new
                {
                    operation = "SET",
                    key = kvp.Key,
                    value = kvp.Value,
                    success = setResponse.Success,
                    error = setResponse.Error
                });
            }

            // Test 2: Get values
            foreach (var kvp in testData)
            {
                var getRequest = new Protos.GetValueRequest { Key = kvp.Key };
                var getResponse = await client.GetValueAsync(getRequest);
                
                results.Add(new
                {
                    operation = "GET",
                    key = kvp.Key,
                    expectedValue = kvp.Value,
                    actualValue = getResponse.Value,
                    found = getResponse.Found,
                    matches = getResponse.Value == kvp.Value,
                    error = getResponse.Error
                });
            }

            // Test 3: List keys
            var listRequest = new Protos.ListKeysRequest { Prefix = "grpc-test", Limit = 20 };
            var listResponse = await client.ListKeysAsync(listRequest);
            
            results.Add(new
            {
                operation = "LIST",
                prefix = "grpc-test",
                keys = listResponse.Keys.ToArray(),
                expectedCount = testData.Count,
                actualCount = listResponse.Keys.Count,
                error = listResponse.Error
            });

            // Test 4: Delete values (if requested)
            if (request.CleanupAfterTest)
            {
                foreach (var kvp in testData)
                {
                    var deleteRequest = new Protos.DeleteValueRequest { Key = kvp.Key };
                    var deleteResponse = await client.DeleteValueAsync(deleteRequest);
                    
                    results.Add(new
                    {
                        operation = "DELETE",
                        key = kvp.Key,
                        success = deleteResponse.Success,
                        error = deleteResponse.Error
                    });
                }
            }

            var summary = new
            {
                totalOperations = results.Count,
                successful = results.Count(r => r.GetType().GetProperty("success")?.GetValue(r) as bool? != false &&
                                              r.GetType().GetProperty("found")?.GetValue(r) as bool? != false &&
                                              string.IsNullOrEmpty(r.GetType().GetProperty("error")?.GetValue(r) as string)),
                failed = results.Count(r => !string.IsNullOrEmpty(r.GetType().GetProperty("error")?.GetValue(r) as string))
            };

            return Ok(new
            {
                testSuite = "Comprehensive gRPC Test",
                summary,
                results,
                success = summary.failed == 0
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error running comprehensive gRPC test");
            return StatusCode(500, new
            {
                testSuite = "Comprehensive gRPC Test",
                success = false,
                error = ex.Message,
                results
            });
        }
    }

    /// <summary>
    /// Get gRPC service health and info
    /// </summary>
    [HttpGet("info")]
    public IActionResult GetGrpcInfo()
    {
        return Ok(new
        {
            service = "NebulaGraph gRPC Test Controller",
            grpcEndpoint = "http://localhost:50000",
            availableOperations = new[]
            {
                "GET /api/grpctest/get/{key} - Test GetValue",
                "POST /api/grpctest/set/{key} - Test SetValue",
                "DELETE /api/grpctest/delete/{key} - Test DeleteValue",
                "GET /api/grpctest/list?prefix=&limit= - Test ListKeys",
                "POST /api/grpctest/comprehensive-test - Run full test suite"
            },
            timestamp = DateTime.UtcNow
        });
    }
}

public class SetValueTestRequest
{
    public string Value { get; set; } = string.Empty;
}

public class ComprehensiveTestRequest
{
    public Dictionary<string, string>? TestData { get; set; }
    public bool CleanupAfterTest { get; set; } = false;
}
