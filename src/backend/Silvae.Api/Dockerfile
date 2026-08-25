FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY Directory.Build.props global.json ./
COPY src/backend/Silvae.Domain/Silvae.Domain.csproj src/backend/Silvae.Domain/
COPY src/backend/Silvae.Application/Silvae.Application.csproj src/backend/Silvae.Application/
COPY src/backend/Silvae.Infrastructure/Silvae.Infrastructure.csproj src/backend/Silvae.Infrastructure/
COPY src/backend/Silvae.Api/Silvae.Api.csproj src/backend/Silvae.Api/
RUN dotnet restore src/backend/Silvae.Api/Silvae.Api.csproj

COPY src/backend/ src/backend/
RUN dotnet publish src/backend/Silvae.Api/Silvae.Api.csproj \
    --configuration Release \
    --output /app/publish \
    --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://0.0.0.0:10000
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 10000
USER $APP_UID
ENTRYPOINT ["dotnet", "Silvae.Api.dll"]
