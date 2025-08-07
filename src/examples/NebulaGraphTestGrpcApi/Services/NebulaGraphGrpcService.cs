using Dapr.Client;
using Grpc.Core;
using NebulaGraphTestGrpcApi.Protos;

namespace NebulaGraphTestGrpcApi.Services;

public class NebulaGraphGrpcService : NebulaGraphService.NebulaGraphServiceBase
{
    private readonly DaprClient _daprClient;
    private readonly ILogger<NebulaGraphGrpcService> _logger;
    private const string StateStoreName = "nebulagraph-state";

    public NebulaGraphGrpcService(DaprClient daprClient, ILogger<NebulaGraphGrpcService> logger)
    {
        _daprClient = daprClient;
        _logger = logger;
    }

    public override async Task<GetValueResponse> GetValue(GetValueRequest request, ServerCallContext context)
    {
        try
        {
            _logger.LogInformation("gRPC: Getting value for key: {Key} from NebulaGraph state store", request.Key);
            var value = await _daprClient.GetStateAsync<string>(StateStoreName, request.Key);
            
            var found = !string.IsNullOrEmpty(value);
            return new GetValueResponse
            {
                Value = value ?? "",
                Found = found,
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
            _logger.LogInformation("gRPC: Setting value for key: {Key} in NebulaGraph state store", request.Key);
            await _daprClient.SaveStateAsync(StateStoreName, request.Key, request.Value);
            
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
            _logger.LogInformation("gRPC: Deleting value for key: {Key} from NebulaGraph state store", request.Key);
            await _daprClient.DeleteStateAsync(StateStoreName, request.Key);
            
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
            _logger.LogInformation("gRPC: Listing keys with prefix: {Prefix}, limit: {Limit} from NebulaGraph state store", request.Prefix, request.Limit);
            
            // Note: Dapr's state store API doesn't have a direct "list keys" method
            // This is a simplified implementation that would need to be enhanced
            // based on the actual NebulaGraph implementation capabilities
            
            _logger.LogWarning("gRPC: ListKeys operation not fully implemented - NebulaGraph state store doesn't expose key listing through standard Dapr state API");
            
            return new ListKeysResponse
            {
                Error = "ListKeys operation not available through standard Dapr state store API"
            };
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
