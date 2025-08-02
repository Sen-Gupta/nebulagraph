using Dapr.Client;
using Grpc.Core;
using NebulaGraphTestApi.Protos;

namespace NebulaGraphTestApi.Services;

public class NebulaGraphGrpcService : NebulaGraphService.NebulaGraphServiceBase
{
    private readonly DaprClient _daprClient;
    private readonly ILogger<NebulaGraphGrpcService> _logger;
    private const string StoreName = "nebulagraph-state";

    public NebulaGraphGrpcService(DaprClient daprClient, ILogger<NebulaGraphGrpcService> logger)
    {
        _daprClient = daprClient;
        _logger = logger;
    }

    public override async Task<GetValueResponse> GetValue(GetValueRequest request, ServerCallContext context)
    {
        try
        {
            _logger.LogInformation("gRPC: Getting value for key: {Key}", request.Key);
            
            var value = await _daprClient.GetStateAsync<string>(StoreName, request.Key);
            
            if (value == null)
            {
                return new GetValueResponse
                {
                    Value = "",
                    Found = false,
                    Error = "Key not found"
                };
            }

            return new GetValueResponse
            {
                Value = value,
                Found = true,
                Error = ""
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "gRPC: Error getting value for key: {Key}", request.Key);
            return new GetValueResponse
            {
                Value = "",
                Found = false,
                Error = ex.Message
            };
        }
    }

    public override async Task<SetValueResponse> SetValue(SetValueRequest request, ServerCallContext context)
    {
        try
        {
            _logger.LogInformation("gRPC: Setting value for key: {Key}", request.Key);
            
            await _daprClient.SaveStateAsync(StoreName, request.Key, request.Value);
            
            return new SetValueResponse
            {
                Success = true,
                Error = ""
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "gRPC: Error setting value for key: {Key}", request.Key);
            return new SetValueResponse
            {
                Success = false,
                Error = ex.Message
            };
        }
    }

    public override async Task<DeleteValueResponse> DeleteValue(DeleteValueRequest request, ServerCallContext context)
    {
        try
        {
            _logger.LogInformation("gRPC: Deleting value for key: {Key}", request.Key);
            
            await _daprClient.DeleteStateAsync(StoreName, request.Key);
            
            return new DeleteValueResponse
            {
                Success = true,
                Error = ""
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "gRPC: Error deleting value for key: {Key}", request.Key);
            return new DeleteValueResponse
            {
                Success = false,
                Error = ex.Message
            };
        }
    }

    public override async Task<ListKeysResponse> ListKeys(ListKeysRequest request, ServerCallContext context)
    {
        try
        {
            _logger.LogInformation("gRPC: Listing keys with prefix: {Prefix}, limit: {Limit}", request.Prefix, request.Limit);
            
            // Note: This is a basic implementation as Dapr doesn't have a built-in list operation
            // In a real scenario, you might need to maintain a separate index or query NebulaGraph directly
            var response = new ListKeysResponse();
            
            // For demonstration, we'll return some test keys
            // In a real implementation, you'd query your state store directly
            if (!string.IsNullOrEmpty(request.Prefix))
            {
                response.Keys.Add($"{request.Prefix}1");
                response.Keys.Add($"{request.Prefix}2");
                response.Keys.Add($"{request.Prefix}3");
            }
            
            response.Error = "";
            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "gRPC: Error listing keys with prefix: {Prefix}", request.Prefix);
            return new ListKeysResponse
            {
                Error = ex.Message
            };
        }
    }
}
