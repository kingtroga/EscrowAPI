# Stage 1: Build & Restore
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy project file and restore dependencies (cached unless .csproj changes)
COPY ["EscrowAPI.csproj", "./"]
RUN dotnet restore "EscrowAPI.csproj"

# Copy the remaining project files and build
COPY . .
RUN dotnet build "EscrowAPI.csproj" -c Release -o /app/build

# Stage 2: Publish optimized binaries
FROM build AS publish
RUN dotnet publish "EscrowAPI.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Stage 3: Final lightweight runtime container
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

# In .NET 8+, ASP.NET Core defaults to port 8080 and runs as non-root user $APP_UID
EXPOSE 8080

USER $APP_UID

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "EscrowAPI.dll"]
