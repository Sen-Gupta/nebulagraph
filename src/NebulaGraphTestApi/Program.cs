using Dapr.Client;
using NebulaGraphTestApi.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers().AddDapr(builder =>
{
    builder.UseJsonSerializationOptions(new System.Text.Json.JsonSerializerOptions
    {
        PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase
    });
});

// Add DaprClient
builder.Services.AddDaprClient();

// Add gRPC services
builder.Services.AddGrpc();

// Add Swagger/OpenAPI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Add Dapr cloud events
app.UseCloudEvents();
app.UseRouting();
app.MapControllers();
app.MapSubscribeHandler();

// Map gRPC service
app.MapGrpcService<NebulaGraphGrpcService>();

app.Run();
