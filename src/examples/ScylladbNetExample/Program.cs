using Dapr.Client;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers().AddDapr(builder =>
{
    builder.UseJsonSerializationOptions(new System.Text.Json.JsonSerializerOptions
    {
        PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase
    });
});

// Add DaprClient for standard gRPC communication with sidecar
builder.Services.AddDaprClient();

// Add Swagger/OpenAPI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
    {
        Title = "ScyllaDB Dapr State Store Example",
        Version = "v1",
        Description = "A comprehensive .NET example demonstrating ScyllaDB Dapr pluggable state store integration with complete CRUD operations, bulk operations, and performance testing."
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/swagger/v1/swagger.json", "ScyllaDB Dapr State Store Example v1");
        options.RoutePrefix = string.Empty;
    });
}

// Add Dapr cloud events
app.UseCloudEvents();
app.UseRouting();
app.MapControllers();
app.MapSubscribeHandler();

app.Run();
