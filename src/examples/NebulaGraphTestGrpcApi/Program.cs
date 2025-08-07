using NebulaGraphTestGrpcApi.Services;
using Dapr.Client;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddGrpc().AddJsonTranscoding();

// Add gRPC reflection for development
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddGrpcReflection();
}

// Add Dapr client
builder.Services.AddSingleton<DaprClient>(provider =>
{
    var daprClientBuilder = new DaprClientBuilder();
    
    // Configure Dapr endpoints from environment variables
    var daprHttpEndpoint = Environment.GetEnvironmentVariable("DAPR_HTTP_ENDPOINT");
    var daprGrpcEndpoint = Environment.GetEnvironmentVariable("DAPR_GRPC_ENDPOINT");
    
    if (!string.IsNullOrEmpty(daprHttpEndpoint))
    {
        var uri = new Uri(daprHttpEndpoint);
        daprClientBuilder.UseHttpEndpoint($"http://{uri.Host}:{uri.Port}");
    }
    
    if (!string.IsNullOrEmpty(daprGrpcEndpoint))
    {
        var uri = new Uri(daprGrpcEndpoint);
        daprClientBuilder.UseGrpcEndpoint($"http://{uri.Host}:{uri.Port}");
    }
    
    return daprClientBuilder.Build();
});

var app = builder.Build();

// Configure the HTTP request pipeline.
app.MapGrpcService<NebulaGraphGrpcService>();

// Enable gRPC reflection in development
if (app.Environment.IsDevelopment())
{
    app.MapGrpcReflectionService();
}
app.MapGet("/", () => "Communication with gRPC endpoints must be made through a gRPC client. To learn how to create a client, visit: https://go.microsoft.com/fwlink/?linkid=2086909");

app.Run();
