using Dapr.Client;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers().AddDapr(daprClientBuilder =>
{
    daprClientBuilder.UseHttpEndpoint("http://localhost:3500")
                     .UseGrpcEndpoint("http://localhost:50001");
});

// Add HttpClient for HTTP API testing
builder.Services.AddHttpClient();
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// Add Swagger/OpenAPI for better API documentation
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { 
        Title = "NebulaGraph Test API", 
        Version = "v1",
        Description = "A comprehensive test API for NebulaGraph Dapr State Store component testing both gRPC and HTTP endpoints"
    });
});

// Add CORS for development
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Add logging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "NebulaGraph Test API v1");
        c.RoutePrefix = "swagger"; // Serve Swagger UI at /swagger
    });
    app.UseCors();
}

app.UseRouting();
app.MapControllers();

// Add health check endpoint
app.MapGet("/health", () => new { 
    status = "healthy", 
    timestamp = DateTime.UtcNow,
    version = "1.0.0"
});

// Add info endpoint
app.MapGet("/info", () => new { 
    name = "NebulaGraph Test API",
    description = "Test API for NebulaGraph Dapr State Store",
    version = "1.0.0",
    environment = app.Environment.EnvironmentName,
    endpoints = new
    {
        grpcTests = "/api/StateStoreTest",
        httpTests = "/api/HttpApiTest", 
        comprehensiveTests = "/api/ComprehensiveTest",
        swagger = "/swagger",
        openapi = "/openapi/v1.json",
        health = "/health"
    }
});

app.Run();
