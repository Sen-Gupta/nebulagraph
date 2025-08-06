using NebulaGraphTestGrpcApi.Services;
using Dapr.Client;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddGrpc();

// Add Dapr client
builder.Services.AddSingleton<DaprClient>(provider =>
{
    return new DaprClientBuilder().Build();
});

var app = builder.Build();

// Configure the HTTP request pipeline.
app.MapGrpcService<NebulaGraphGrpcService>();
app.MapGet("/", () => "Communication with gRPC endpoints must be made through a gRPC client. To learn how to create a client, visit: https://go.microsoft.com/fwlink/?linkid=2086909");

app.Run();
