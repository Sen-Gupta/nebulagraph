FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 5000

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["NebulaGraphTestGrpcApi.csproj", "."]
RUN dotnet restore "./NebulaGraphTestGrpcApi.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "NebulaGraphTestGrpcApi.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "NebulaGraphTestGrpcApi.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "NebulaGraphTestGrpcApi.dll"]
