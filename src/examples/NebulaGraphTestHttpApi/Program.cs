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

// Add DaprClient configured for HTTP only
builder.Services.AddDaprClient(daprClientBuilder =>
{
    daprClientBuilder.UseHttpEndpoint(Environment.GetEnvironmentVariable("DAPR_HTTP_ENDPOINT") ?? "http://localhost:3500");
});

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

app.Run();
