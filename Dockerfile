# Build multi-stage. La versión llega por --build-arg VERSION y se inyecta al
# assembly con MinVer (/p:MinVerVersionOverride), así el .git no entra a la imagen.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
ARG VERSION=0.0.0-dev
COPY ProveedoresApiCore/ProveedoresApiCore.csproj ProveedoresApiCore/
RUN dotnet restore ProveedoresApiCore/ProveedoresApiCore.csproj
COPY ProveedoresApiCore/ ProveedoresApiCore/
RUN dotnet publish ProveedoresApiCore/ProveedoresApiCore.csproj -c Release -o /app/publish \
    /p:UseAppHost=false /p:MinVerVersionOverride=$VERSION

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
ARG VERSION=0.0.0-dev
LABEL org.opencontainers.image.version=$VERSION
COPY --from=build /app/publish .
EXPOSE 8080
# curl no viene en la imagen aspnet; hace falta para el HEALTHCHECK.
# --only-upgrade apt: la base trae un apt con CVE HIGH (trivy) que ya tiene fix publicado.
RUN apt-get update \
    && apt-get install -y --no-install-recommends --only-upgrade apt \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
# La imagen base trae el usuario `app`; sin esto el proceso corre como root.
# ASPNETCORE_HTTP_PORTS=8080 ya es la base, así que no necesita puerto privilegiado.
USER $APP_UID
# Apunta a liveness: no debe fallar porque la base esté caída.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -fsS http://localhost:8080/health/live || exit 1
ENTRYPOINT ["dotnet", "ProveedoresApiCore.dll"]
