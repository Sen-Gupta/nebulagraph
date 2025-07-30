using Microsoft.AspNetCore.Mvc;
using Dapr.Client;
using System.Text;
using System.Text.Json;

namespace NebulaGraphTest.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ComprehensiveTestController : ControllerBase
{
    private readonly DaprClient _daprClient;
    private readonly HttpClient _httpClient;
    private readonly ILogger<ComprehensiveTestController> _logger;
    private const string StateStoreName = "nebulagraph-state";
    private const string DaprBaseUrl = "http://localhost:3500";

    public ComprehensiveTestController(
        DaprClient daprClient, 
        HttpClient httpClient, 
        ILogger<ComprehensiveTestController> logger)
    {
        _daprClient = daprClient;
        _httpClient = httpClient;
        _logger = logger;
    }

    /// <summary>
    /// Run comprehensive tests comparing gRPC vs HTTP performance and functionality
    /// </summary>
    [HttpPost("run-all-tests")]
    public async Task<IActionResult> RunAllTests()
    {
        var testResults = new List<object>();
        var startTime = DateTime.UtcNow;

        try
        {
            _logger.LogInformation("Starting comprehensive NebulaGraph state store tests");

            // Test 1: Save operations
            var saveResults = await TestSaveOperations();
            testResults.Add(saveResults);

            // Test 2: Get operations
            var getResults = await TestGetOperations();
            testResults.Add(getResults);

            // Test 3: Bulk operations
            var bulkResults = await TestBulkOperations();
            testResults.Add(bulkResults);

            // Test 4: Delete operations
            var deleteResults = await TestDeleteOperations();
            testResults.Add(deleteResults);

            // Test 5: Error handling
            var errorResults = await TestErrorHandling();
            testResults.Add(errorResults);

            var endTime = DateTime.UtcNow;
            var totalDuration = endTime - startTime;

            return Ok(new
            {
                success = true,
                message = "Comprehensive tests completed",
                startTime = startTime,
                endTime = endTime,
                totalDuration = totalDuration.TotalMilliseconds,
                testResults = testResults
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during comprehensive tests");
            return StatusCode(500, new
            {
                success = false,
                error = ex.Message,
                testResults = testResults
            });
        }
    }

    private async Task<object> TestSaveOperations()
    {
        _logger.LogInformation("Testing save operations");
        var results = new List<object>();

        // gRPC Save Test
        var grpcStart = DateTime.UtcNow;
        try
        {
            await _daprClient.SaveStateAsync(StateStoreName, "grpc-test-key", new { 
                message = "Hello from gRPC", 
                timestamp = DateTime.UtcNow,
                method = "gRPC"
            });
            var grpcEnd = DateTime.UtcNow;
            
            results.Add(new {
                method = "gRPC",
                operation = "Save",
                success = true,
                duration = (grpcEnd - grpcStart).TotalMilliseconds
            });
        }
        catch (Exception ex)
        {
            results.Add(new {
                method = "gRPC",
                operation = "Save",
                success = false,
                error = ex.Message
            });
        }

        // HTTP Save Test
        var httpStart = DateTime.UtcNow;
        try
        {
            var stateData = new[]
            {
                new { 
                    key = "http-test-key", 
                    value = new { 
                        message = "Hello from HTTP", 
                        timestamp = DateTime.UtcNow,
                        method = "HTTP"
                    }
                }
            };
            
            var json = JsonSerializer.Serialize(stateData);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            var response = await _httpClient.PostAsync($"{DaprBaseUrl}/v1.0/state/{StateStoreName}", content);
            var httpEnd = DateTime.UtcNow;
            
            results.Add(new {
                method = "HTTP",
                operation = "Save",
                success = response.IsSuccessStatusCode,
                statusCode = (int)response.StatusCode,
                duration = (httpEnd - httpStart).TotalMilliseconds
            });
        }
        catch (Exception ex)
        {
            results.Add(new {
                method = "HTTP",
                operation = "Save",
                success = false,
                error = ex.Message
            });
        }

        return new { testName = "Save Operations", results = results };
    }

    private async Task<object> TestGetOperations()
    {
        _logger.LogInformation("Testing get operations");
        var results = new List<object>();

        // gRPC Get Test
        var grpcStart = DateTime.UtcNow;
        try
        {
            var result = await _daprClient.GetStateAsync<object>(StateStoreName, "grpc-test-key");
            var grpcEnd = DateTime.UtcNow;
            
            results.Add(new {
                method = "gRPC",
                operation = "Get",
                success = true,
                hasValue = result != null,
                duration = (grpcEnd - grpcStart).TotalMilliseconds
            });
        }
        catch (Exception ex)
        {
            results.Add(new {
                method = "gRPC",
                operation = "Get",
                success = false,
                error = ex.Message
            });
        }

        // HTTP Get Test
        var httpStart = DateTime.UtcNow;
        try
        {
            var response = await _httpClient.GetAsync($"{DaprBaseUrl}/v1.0/state/{StateStoreName}/http-test-key");
            var content = await response.Content.ReadAsStringAsync();
            var httpEnd = DateTime.UtcNow;
            
            results.Add(new {
                method = "HTTP",
                operation = "Get",
                success = response.IsSuccessStatusCode,
                statusCode = (int)response.StatusCode,
                hasValue = !string.IsNullOrEmpty(content),
                duration = (httpEnd - httpStart).TotalMilliseconds
            });
        }
        catch (Exception ex)
        {
            results.Add(new {
                method = "HTTP",
                operation = "Get",
                success = false,
                error = ex.Message
            });
        }

        return new { testName = "Get Operations", results = results };
    }

    private async Task<object> TestBulkOperations()
    {
        _logger.LogInformation("Testing bulk operations");
        var results = new List<object>();

        // gRPC Bulk Save Test
        var grpcStart = DateTime.UtcNow;
        try
        {
            var states = new List<SaveStateItem<object>>();
            for (int i = 1; i <= 5; i++)
            {
                states.Add(new SaveStateItem<object>($"bulk-grpc-{i}", new { 
                    id = i, 
                    message = $"Bulk item {i} via gRPC",
                    timestamp = DateTime.UtcNow
                }, ""));
            }
            
            await _daprClient.SaveBulkStateAsync(StateStoreName, states);
            var grpcEnd = DateTime.UtcNow;
            
            results.Add(new {
                method = "gRPC",
                operation = "BulkSave",
                success = true,
                itemCount = states.Count,
                duration = (grpcEnd - grpcStart).TotalMilliseconds
            });
        }
        catch (Exception ex)
        {
            results.Add(new {
                method = "gRPC",
                operation = "BulkSave",
                success = false,
                error = ex.Message
            });
        }

        // gRPC Bulk Get Test
        grpcStart = DateTime.UtcNow;
        try
        {
            var keys = new[] { "bulk-grpc-1", "bulk-grpc-2", "bulk-grpc-3", "bulk-grpc-4", "bulk-grpc-5" };
            var bulkResults = await _daprClient.GetBulkStateAsync(StateStoreName, keys, parallelism: 5);
            var grpcEnd = DateTime.UtcNow;
            
            results.Add(new {
                method = "gRPC",
                operation = "BulkGet",
                success = true,
                itemsRequested = keys.Length,
                itemsReturned = bulkResults.Count(),
                duration = (grpcEnd - grpcStart).TotalMilliseconds
            });
        }
        catch (Exception ex)
        {
            results.Add(new {
                method = "gRPC",
                operation = "BulkGet",
                success = false,
                error = ex.Message
            });
        }

        // HTTP Bulk Get Test
        var httpStart = DateTime.UtcNow;
        try
        {
            var keys = new[] { "bulk-grpc-1", "bulk-grpc-2", "bulk-grpc-3" };
            var requestData = new { keys = keys };
            var json = JsonSerializer.Serialize(requestData);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            
            var response = await _httpClient.PostAsync($"{DaprBaseUrl}/v1.0/state/{StateStoreName}/bulk", content);
            var responseContent = await response.Content.ReadAsStringAsync();
            var httpEnd = DateTime.UtcNow;
            
            results.Add(new {
                method = "HTTP",
                operation = "BulkGet",
                success = response.IsSuccessStatusCode,
                statusCode = (int)response.StatusCode,
                itemsRequested = keys.Length,
                duration = (httpEnd - httpStart).TotalMilliseconds
            });
        }
        catch (Exception ex)
        {
            results.Add(new {
                method = "HTTP",
                operation = "BulkGet",
                success = false,
                error = ex.Message
            });
        }

        return new { testName = "Bulk Operations", results = results };
    }

    private async Task<object> TestDeleteOperations()
    {
        _logger.LogInformation("Testing delete operations");
        var results = new List<object>();

        // gRPC Delete Test
        var grpcStart = DateTime.UtcNow;
        try
        {
            await _daprClient.DeleteStateAsync(StateStoreName, "grpc-test-key");
            var grpcEnd = DateTime.UtcNow;
            
            results.Add(new {
                method = "gRPC",
                operation = "Delete",
                success = true,
                duration = (grpcEnd - grpcStart).TotalMilliseconds
            });
        }
        catch (Exception ex)
        {
            results.Add(new {
                method = "gRPC",
                operation = "Delete",
                success = false,
                error = ex.Message
            });
        }

        // HTTP Delete Test
        var httpStart = DateTime.UtcNow;
        try
        {
            var response = await _httpClient.DeleteAsync($"{DaprBaseUrl}/v1.0/state/{StateStoreName}/http-test-key");
            var httpEnd = DateTime.UtcNow;
            
            results.Add(new {
                method = "HTTP",
                operation = "Delete",
                success = response.IsSuccessStatusCode,
                statusCode = (int)response.StatusCode,
                duration = (httpEnd - httpStart).TotalMilliseconds
            });
        }
        catch (Exception ex)
        {
            results.Add(new {
                method = "HTTP",
                operation = "Delete",
                success = false,
                error = ex.Message
            });
        }

        return new { testName = "Delete Operations", results = results };
    }

    private async Task<object> TestErrorHandling()
    {
        _logger.LogInformation("Testing error handling");
        var results = new List<object>();

        // Test getting non-existent key via gRPC
        try
        {
            var result = await _daprClient.GetStateAsync<object>(StateStoreName, "non-existent-key");
            results.Add(new {
                method = "gRPC",
                operation = "GetNonExistent",
                success = true,
                hasValue = result != null,
                message = "gRPC handles missing keys gracefully"
            });
        }
        catch (Exception ex)
        {
            results.Add(new {
                method = "gRPC",
                operation = "GetNonExistent",
                success = false,
                error = ex.Message
            });
        }

        // Test getting non-existent key via HTTP
        try
        {
            var response = await _httpClient.GetAsync($"{DaprBaseUrl}/v1.0/state/{StateStoreName}/non-existent-key");
            var content = await response.Content.ReadAsStringAsync();
            
            results.Add(new {
                method = "HTTP",
                operation = "GetNonExistent",
                success = response.IsSuccessStatusCode,
                statusCode = (int)response.StatusCode,
                hasValue = !string.IsNullOrEmpty(content),
                message = "HTTP handles missing keys gracefully"
            });
        }
        catch (Exception ex)
        {
            results.Add(new {
                method = "HTTP",
                operation = "GetNonExistent",
                success = false,
                error = ex.Message
            });
        }

        return new { testName = "Error Handling", results = results };
    }

    /// <summary>
    /// Performance comparison between gRPC and HTTP
    /// </summary>
    [HttpPost("performance-test")]
    public async Task<IActionResult> RunPerformanceTest([FromQuery] int iterations = 10)
    {
        var results = new List<object>();
        
        _logger.LogInformation("Running performance test with {Iterations} iterations", iterations);

        // gRPC Performance Test
        var grpcTimes = new List<double>();
        for (int i = 0; i < iterations; i++)
        {
            var start = DateTime.UtcNow;
            await _daprClient.SaveStateAsync(StateStoreName, $"perf-grpc-{i}", new { iteration = i, timestamp = DateTime.UtcNow });
            var result = await _daprClient.GetStateAsync<object>(StateStoreName, $"perf-grpc-{i}");
            var end = DateTime.UtcNow;
            grpcTimes.Add((end - start).TotalMilliseconds);
        }

        // HTTP Performance Test
        var httpTimes = new List<double>();
        for (int i = 0; i < iterations; i++)
        {
            var start = DateTime.UtcNow;
            
            // Save via HTTP
            var stateData = new[] { new { key = $"perf-http-{i}", value = new { iteration = i, timestamp = DateTime.UtcNow } } };
            var json = JsonSerializer.Serialize(stateData);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            await _httpClient.PostAsync($"{DaprBaseUrl}/v1.0/state/{StateStoreName}", content);
            
            // Get via HTTP
            await _httpClient.GetAsync($"{DaprBaseUrl}/v1.0/state/{StateStoreName}/perf-http-{i}");
            
            var end = DateTime.UtcNow;
            httpTimes.Add((end - start).TotalMilliseconds);
        }

        return Ok(new
        {
            success = true,
            iterations = iterations,
            grpcPerformance = new
            {
                method = "gRPC",
                averageTime = grpcTimes.Average(),
                minTime = grpcTimes.Min(),
                maxTime = grpcTimes.Max(),
                totalTime = grpcTimes.Sum()
            },
            httpPerformance = new
            {
                method = "HTTP",
                averageTime = httpTimes.Average(),
                minTime = httpTimes.Min(),
                maxTime = httpTimes.Max(),
                totalTime = httpTimes.Sum()
            },
            comparison = new
            {
                grpcFasterBy = httpTimes.Average() - grpcTimes.Average(),
                grpcFasterPercent = Math.Round(((httpTimes.Average() - grpcTimes.Average()) / httpTimes.Average()) * 100, 2)
            }
        });
    }
}
