using Dapr.Client;
using Grpc.Core;
using NebulaGraphTestApi.Protos;

namespace NebulaGraphTestHttpApi.Services;

public class NebulaGraphGrpcService : NebulaGraphService.NebulaGraphServiceBase
{
    private readonly DaprClient _daprClient;
    private readonly ILogger<NebulaGraphGrpcService> _logger;
    private const string MainComponentAppId = "nebulagraph-test";

    public NebulaGraphGrpcService(DaprClient daprClient, ILogger<NebulaGraphGrpcService> logger)
    {
        _daprClient = daprClient;
        _logger = logger;
    }

    public override async Task<GetValueResponse> GetValue(GetValueRequest request, ServerCallContext context)
    {
        try
        {
            _logger.LogInformation("gRPC: Getting value for key: {Key} via Dapr gRPC service invocation", request.Key);
            var response = await _daprClient.InvokeMethodGrpcAsync<GetValueRequest, GetValueResponse>(
                appId: MainComponentAppId,
                methodName: "GetValue",
                data: request
            );
            return response;
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
            _logger.LogInformation("gRPC: Setting value for key: {Key} via Dapr gRPC service invocation", request.Key);
            var response = await _daprClient.InvokeMethodGrpcAsync<SetValueRequest, SetValueResponse>(
                appId: MainComponentAppId,
                methodName: "SetValue",
                data: request
            );
            return response;
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
            _logger.LogInformation("gRPC: Deleting value for key: {Key} via Dapr gRPC service invocation", request.Key);
            var response = await _daprClient.InvokeMethodGrpcAsync<DeleteValueRequest, DeleteValueResponse>(
                appId: MainComponentAppId,
                methodName: "DeleteValue",
                data: request
            );
            return response;
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
            _logger.LogInformation("gRPC: Listing keys with prefix: {Prefix}, limit: {Limit} via Dapr gRPC service invocation", request.Prefix, request.Limit);
            var response = await _daprClient.InvokeMethodGrpcAsync<ListKeysRequest, ListKeysResponse>(
                appId: MainComponentAppId,
                methodName: "ListKeys",
                data: request
            );
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
