using Microsoft.AspNetCore.Mvc;
using System.Text;
using System.Text.Json;

namespace NebulaGraphTest.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HttpApiTestController : ControllerBase
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<HttpApiTestController> _logger;
    private const string DaprBaseUrl = "http://localhost:3500";
    private const string StateStoreName = "nebulagraph-state";

    public HttpApiTestController(HttpClient httpClient, ILogger<HttpApiTestController> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    /// <summary>
    /// Test saving state using direct HTTP API calls to Dapr
    /// </summary>
    [HttpPost("save-http/{key}")]
    public async Task<IActionResult> SaveStateHttp(string key, [FromBody] object value)
    {
        try
        {
            _logger.LogInformation("Saving state via HTTP: Key={Key}, Value={Value}", key, value);
            
            var stateData = new[]
            {
                new { key = key, value = value }
            };
            
            var json = JsonSerializer.Serialize(stateData);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            
            var url = $"{DaprBaseUrl}/v1.0/state/{StateStoreName}";
            var response = await _httpClient.PostAsync(url, content);
            
            if (response.IsSuccessStatusCode)
            {
                return Ok(new { 
                    success = true, 
                    message = "State saved successfully via HTTP",
                    key = key,
                    method = "HTTP",
                    statusCode = (int)response.StatusCode
                });
            }
            else
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                return StatusCode((int)response.StatusCode, new { 
                    success = false, 
                    error = errorContent,
                    method = "HTTP"
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving state via HTTP");
            return StatusCode(500, new { 
                success = false, 
                error = ex.Message,
                method = "HTTP"
            });
        }
    }

    /// <summary>
    /// Test retrieving state using direct HTTP API calls to Dapr
    /// </summary>
    [HttpGet("get-http/{key}")]
    public async Task<IActionResult> GetStateHttp(string key)
    {
        try
        {
            _logger.LogInformation("Getting state via HTTP: Key={Key}", key);
            
            var url = $"{DaprBaseUrl}/v1.0/state/{StateStoreName}/{key}";
            var response = await _httpClient.GetAsync(url);
            
            if (response.IsSuccessStatusCode)
            {
                var content = await response.Content.ReadAsStringAsync();
                object? value = null;
                
                if (!string.IsNullOrEmpty(content))
                {
                    try
                    {
                        value = JsonSerializer.Deserialize<object>(content);
                    }
                    catch
                    {
                        value = content; // If not JSON, return as string
                    }
                }
                
                return Ok(new { 
                    success = true, 
                    key = key,
                    value = value,
                    method = "HTTP",
                    statusCode = (int)response.StatusCode
                });
            }
            else
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                return StatusCode((int)response.StatusCode, new { 
                    success = false, 
                    error = errorContent,
                    method = "HTTP"
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting state via HTTP");
            return StatusCode(500, new { 
                success = false, 
                error = ex.Message,
                method = "HTTP"
            });
        }
    }

    /// <summary>
    /// Test deleting state using direct HTTP API calls to Dapr
    /// </summary>
    [HttpDelete("delete-http/{key}")]
    public async Task<IActionResult> DeleteStateHttp(string key)
    {
        try
        {
            _logger.LogInformation("Deleting state via HTTP: Key={Key}", key);
            
            var url = $"{DaprBaseUrl}/v1.0/state/{StateStoreName}/{key}";
            var response = await _httpClient.DeleteAsync(url);
            
            if (response.IsSuccessStatusCode)
            {
                return Ok(new { 
                    success = true, 
                    message = "State deleted successfully via HTTP",
                    key = key,
                    method = "HTTP",
                    statusCode = (int)response.StatusCode
                });
            }
            else
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                return StatusCode((int)response.StatusCode, new { 
                    success = false, 
                    error = errorContent,
                    method = "HTTP"
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting state via HTTP");
            return StatusCode(500, new { 
                success = false, 
                error = ex.Message,
                method = "HTTP"
            });
        }
    }

    /// <summary>
    /// Test bulk state retrieval using direct HTTP API calls to Dapr
    /// </summary>
    [HttpPost("bulk-get-http")]
    public async Task<IActionResult> BulkGetStateHttp([FromBody] string[] keys)
    {
        try
        {
            _logger.LogInformation("Bulk getting {Count} states via HTTP", keys.Length);
            
            var requestData = new { keys = keys };
            var json = JsonSerializer.Serialize(requestData);
            var content = new StringContent(json, Encoding.UTF8, "application/json");
            
            var url = $"{DaprBaseUrl}/v1.0/state/{StateStoreName}/bulk";
            var response = await _httpClient.PostAsync(url, content);
            
            if (response.IsSuccessStatusCode)
            {
                var responseContent = await response.Content.ReadAsStringAsync();
                var results = JsonSerializer.Deserialize<JsonElement[]>(responseContent);
                
                var states = new Dictionary<string, object?>();
                foreach (var result in results)
                {
                    if (result.TryGetProperty("key", out var keyElement) && 
                        result.TryGetProperty("data", out var dataElement))
                    {
                        var key = keyElement.GetString();
                        var data = dataElement.ValueKind == JsonValueKind.String ? 
                            dataElement.GetString() : 
                            dataElement.GetRawText();
                        
                        if (key != null)
                        {
                            states[key] = data;
                        }
                    }
                }
                
                return Ok(new { 
                    success = true, 
                    count = states.Count,
                    states = states,
                    method = "HTTP",
                    statusCode = (int)response.StatusCode
                });
            }
            else
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                return StatusCode((int)response.StatusCode, new { 
                    success = false, 
                    error = errorContent,
                    method = "HTTP"
                });
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error bulk getting states via HTTP");
            return StatusCode(500, new { 
                success = false, 
                error = ex.Message,
                method = "HTTP"
            });
        }
    }

    /// <summary>
    /// Test Dapr health endpoint
    /// </summary>
    [HttpGet("health")]
    public async Task<IActionResult> CheckDaprHealth()
    {
        try
        {
            var url = $"{DaprBaseUrl}/v1.0/healthz";
            var response = await _httpClient.GetAsync(url);
            
            var content = await response.Content.ReadAsStringAsync();
            
            return Ok(new { 
                success = response.IsSuccessStatusCode,
                statusCode = (int)response.StatusCode,
                response = content,
                method = "HTTP"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking Dapr health");
            return StatusCode(500, new { 
                success = false, 
                error = ex.Message,
                method = "HTTP"
            });
        }
    }
}
