# Use the official .NET 9.0.7 runtime as base image
FROM mcr.microsoft.com/dotnet/aspnet:9.0.7 AS base
WORKDIR /app
EXPOSE 80

# Use the .NET 9.0.7 SDK for building
FROM mcr.microsoft.com/dotnet/sdk:9.0.7 AS build
WORKDIR /src
COPY ["NebulaGraphTestApi.csproj", "./"]
RUN dotnet restore "NebulaGraphTestApi.csproj"
COPY . .
WORKDIR "/src"
RUN dotnet build "NebulaGraphTestApi.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "NebulaGraphTestApi.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "NebulaGraphTestApi.dll"]
