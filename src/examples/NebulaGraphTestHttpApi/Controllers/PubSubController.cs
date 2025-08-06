using Microsoft.AspNetCore.Mvc;
using Dapr;
using Dapr.Client;
using System.Text.Json;

namespace NebulaGraphTestHttpApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PubSubController : ControllerBase
{
    private readonly ILogger<PubSubController> _logger;
    private readonly DaprClient _daprClient;

    public PubSubController(ILogger<PubSubController> logger, DaprClient daprClient)
    {
        _logger = logger;
        _daprClient = daprClient;
    }

    /// <summary>
    /// Publishes a message to Redis pub/sub
    /// </summary>
    [HttpPost("publish/{topic}")]
    public async Task<IActionResult> PublishMessage(string topic, [FromBody] object message)
    {
        try
        {
            _logger.LogInformation("Publishing message to topic: {Topic}", topic);
            
            await _daprClient.PublishEventAsync("redis-pubsub", topic, message);
            
            // Also store the message in NebulaGraph state store for persistence
            var messageId = Guid.NewGuid().ToString();
            var messageData = new
            {
                Id = messageId,
                Topic = topic,
                Message = message,
                Timestamp = DateTime.UtcNow,
                Status = "published"
            };
            
            await _daprClient.SaveStateAsync("nebulagraph-state", $"message:{messageId}", messageData);
            
            _logger.LogInformation("Message published successfully with ID: {MessageId}", messageId);
            
            return Ok(new { MessageId = messageId, Status = "Published", Topic = topic });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error publishing message to topic: {Topic}", topic);
            return StatusCode(500, $"Error publishing message: {ex.Message}");
        }
    }

    /// <summary>
    /// Subscribes to messages from Redis pub/sub
    /// </summary>
    [Topic("redis-pubsub", "orders")]
    [Topic("redis-pubsub", "notifications")]
    [Topic("redis-pubsub", "events")]
    [HttpPost("subscribe")]
    public async Task<IActionResult> HandleMessage([FromBody] JsonElement messageData)
    {
        try
        {
            var topicHeader = Request.Headers["ce-topic"].FirstOrDefault();
            var sourceHeader = Request.Headers["ce-source"].FirstOrDefault();
            
            _logger.LogInformation("Received message from topic: {Topic}, source: {Source}", 
                topicHeader, sourceHeader);
            
            // Process the message and store the received event in NebulaGraph
            var eventId = Guid.NewGuid().ToString();
            var eventData = new
            {
                Id = eventId,
                Topic = topicHeader,
                Source = sourceHeader,
                Data = messageData,
                ReceivedAt = DateTime.UtcNow,
                Status = "processed"
            };
            
            await _daprClient.SaveStateAsync("nebulagraph-state", $"event:{eventId}", eventData);
            
            _logger.LogInformation("Message processed and stored with ID: {EventId}", eventId);
            
            return Ok(new { EventId = eventId, Status = "Processed" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing received message");
            return StatusCode(500, $"Error processing message: {ex.Message}");
        }
    }

    /// <summary>
    /// Gets all published messages from NebulaGraph state store
    /// </summary>
    [HttpGet("messages")]
    public async Task<IActionResult> GetMessages()
    {
        try
        {
            _logger.LogInformation("Retrieving all messages from state store");
            
            // For demo purposes, we'll retrieve a few known message keys
            // In a real application, you might use a query or maintain an index
            var messages = new List<object>();
            
            // Try to get recent messages (this is a simplified approach)
            for (int i = 0; i < 10; i++)
            {
                try
                {
                    var messageKey = $"message:recent-{i}";
                    var message = await _daprClient.GetStateAsync<object>("nebulagraph-state", messageKey);
                    if (message != null)
                    {
                        messages.Add(message);
                    }
                }
                catch
                {
                    // Message doesn't exist, continue
                }
            }
            
            return Ok(new { Messages = messages, Count = messages.Count });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving messages");
            return StatusCode(500, $"Error retrieving messages: {ex.Message}");
        }
    }

    /// <summary>
    /// Gets all processed events from NebulaGraph state store
    /// </summary>
    [HttpGet("events")]
    public async Task<IActionResult> GetEvents()
    {
        try
        {
            _logger.LogInformation("Retrieving all events from state store");
            
            var events = new List<object>();
            
            // Try to get recent events (this is a simplified approach)
            for (int i = 0; i < 10; i++)
            {
                try
                {
                    var eventKey = $"event:recent-{i}";
                    var eventData = await _daprClient.GetStateAsync<object>("nebulagraph-state", eventKey);
                    if (eventData != null)
                    {
                        events.Add(eventData);
                    }
                }
                catch
                {
                    // Event doesn't exist, continue
                }
            }
            
            return Ok(new { Events = events, Count = events.Count });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving events");
            return StatusCode(500, $"Error retrieving events: {ex.Message}");
        }
    }

    /// <summary>
    /// Health check for pub/sub connectivity
    /// </summary>
    [HttpGet("health")]
    public async Task<IActionResult> HealthCheck()
    {
        try
        {
            // Test Redis pub/sub by publishing a health check message
            var healthMessage = new
            {
                Type = "health-check",
                Timestamp = DateTime.UtcNow,
                ServiceName = "NebulaGraphTestApi"
            };
            
            await _daprClient.PublishEventAsync("redis-pubsub", "health", healthMessage);
            
            // Test NebulaGraph state store
            var healthKey = "health:pubsub-controller";
            var healthData = new
            {
                LastCheck = DateTime.UtcNow,
                Status = "healthy",
                Component = "PubSubController"
            };
            
            await _daprClient.SaveStateAsync("nebulagraph-state", healthKey, healthData);
            var retrievedHealth = await _daprClient.GetStateAsync<object>("nebulagraph-state", healthKey);
            
            return Ok(new 
            { 
                Status = "Healthy",
                PubSub = "Redis connectivity OK",
                StateStore = "NebulaGraph connectivity OK",
                Timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Health check failed");
            return StatusCode(500, new
            {
                Status = "Unhealthy",
                Error = ex.Message,
                Timestamp = DateTime.UtcNow
            });
        }
    }
}
