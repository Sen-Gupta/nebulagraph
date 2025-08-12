# Use the official .NET 9.0 runtime as base image
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 80

# Use the .NET 9.0 SDK for building
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["DotNetDaprClient.csproj", "./"]
RUN dotnet restore "DotNetDaprClient.csproj"
COPY . .
WORKDIR "/src"
RUN dotnet build "DotNetDaprClient.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "DotNetDaprClient.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "DotNetDaprClient.dll"]
