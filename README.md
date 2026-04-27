# docker-dozerdb-publish

DozerDB images are available in the Docker [image library](https://hub.docker.com/r/boikovsa/dozerdb).

This repository provides Dockerfiles for published releases of the full DozerDB distribution, which is built upon Neo4j with additional DozerDB assets. 

While this repository is forked from [`neo4j/docker-neo4j`](https://github.com/neo4j/docker-neo4j), we do not make updates to the Neo4j repository itself. Instead, we modify select files here to integrate DozerDB-specific components before publishing.

# Building the images.

To build multi-platform Docker images compatible with both AMD64 and ARM architectures (including ARM v8), we use Docker’s buildx feature. The command below allows you to build and push the image to Docker Hub, tagging it with the specific DozerDB and Neo4j versions and designating it as the latest release.

```

$env:DOCKER_BUILDKIT='0'
docker build --no-cache `
  --tag dozerdb:2026.04.1-ubuntu `
  --build-arg NEO4J_URI=http://host.docker.internal:8765/dozerdb-2026.04.1-unix.tar.gz `
  "2026.04.1/ubuntu/dozerdb"
Remove-Item Env:DOCKER_BUILDKIT

docker push 

```

# Notes on building image from local distribution

If you want to build an image with a local distribution, then you may need to modify the Dockerfile line that pulls down the distribution from a remote url.
For example copying the file instead of using curl.

```
ARG NEO4J_URI=http://host.docker.internal:8765/dozerdb-2026.04.1-unix.tar.gz

...

RUN apt-get update \
    && wget --quiet --timeout=60 --tries=20 --retry-connrefused "${NEO4J_URI}" \

```


# Step-by-Step Guide for building and publish DozerDB

This guide shows how to:
- build DozerDB projects (`neo4j`, `dozerdb-core`, `dozerdb-browser`, `dozerdb-plugin`),
- prepare the final `dozerdb-<version>-unix.tar.gz`,
- build and scan Docker images,
- publish final tags to Docker Hub.

All commands are written for PowerShell on Windows.

## 1) Prerequisites

- JDK 21 (required for Neo4j and `dozerdb-core`)
- Maven 3.9+
- Node.js 20+ and Yarn 1.x (for `dozerdb-browser`)
- Docker Desktop with Buildx
- Trivy (recommended for vulnerability checks)
- Docker Hub account with push permission

Repository root used in this guide:
- `d:\GIT\RNTG-DATA\DB_BI\nsd\CodeScope\dozer`

## 2) Build Neo4j baseline artifacts locally

This installs Neo4j parent/modules into your local Maven repository so downstream builds can resolve `org.neo4j:*:2026.03.0`.

```powershell
Set-Location "d:\GIT\RNTG-DATA\DB_BI\nsd\CodeScope\dozer\neo4j"
mvn -N -DskipTests install
mvn -DskipTests -DskipITs install
```

## 3) Build `dozerdb-core`

```powershell
Set-Location "d:\GIT\RNTG-DATA\DB_BI\nsd\CodeScope\dozer\dozerdb-core"
mvn -DskipTests clean install
```

Expected artifact:
- `dozerdb-core\core\target\dozerdb-core-2026.03.0-1.1.0.jar`

## 4) Build `dozerdb-browser`

```powershell
Set-Location "d:\GIT\RNTG-DATA\DB_BI\nsd\CodeScope\dozer\dozerdb-browser"
yarn install
yarn build
yarn prepare-jar
mvn -DskipTests clean install
```

Expected Maven artifact:
- `org.dozerdb.client:dozerdb-browser:2026.04.1` in local `.m2`

## 5) Build `dozerdb-plugin` (final plugin jar)

The plugin shades `dozerdb-core` + `dozerdb-browser` versions configured in `dozerdb-plugin/pom.xml`.

```powershell
Set-Location "d:\GIT\RNTG-DATA\DB_BI\nsd\CodeScope\dozer\dozerdb-plugin"
mvn -DskipTests clean package
```

Expected artifact:
- `dozerdb-plugin\target\dozerdb-plugin-2026.04.1.jar`

## 6) Prepare `dozerdb-2026.04.1-unix.tar.gz`

This is the exact style to remediate Java vulnerabilities: rebuild against Neo4j `2026.03.0`, create a fresh unix distro tarball, inject DozerDB artifacts, and pin checksum in Dockerfiles.

### 6.1 Inputs used

- Baseline distro tarball:  
  `neo4j\packaging\standalone\target\neo4j-community-2026.03.0-unix.tar.gz`
- Plugin jar (shaded with core+browser):  
  `dozerdb-plugin\target\dozerdb-plugin-2026.04.1.jar`
- Final output tarball path:  
  `docker-dozerdb-publish\2026.04.1\ubuntu\dozerdb\dozerdb-2026.04.1-unix.tar.gz`
- APOC line used in this release: `2026.03.0` (downloaded during Docker build)

### 6.2 Assembly steps (conversation workflow)

```powershell
# 1) Work folder
$root = "d:\GIT\RNTG-DATA\DB_BI\nsd\CodeScope\dozer"
$work = Join-Path $root "docker-dozerdb-publish\2026.04.1\ubuntu\dozerdb\build-remediate"
New-Item -ItemType Directory -Force -Path $work | Out-Null
Set-Location $work

# 2) Expand fresh Neo4j baseline
tar -xf "$root\neo4j\packaging\standalone\target\neo4j-community-2026.03.0-unix.tar.gz"

# 3) Normalize folder name to dozerdb release root
if (Test-Path ".\neo4j-community-2026.03.0") {
  Rename-Item ".\neo4j-community-2026.03.0" "dozerdb-2026.04.1"
}

# 4) Inject DozerDB plugin (contains aligned core+browser payload)
Copy-Item "$root\dozerdb-plugin\target\dozerdb-plugin-2026.04.1.jar" `
  ".\dozerdb-2026.04.1\plugins\" -Force
```

### 6.3 Repack tarball and compute checksum

```powershell
Set-Location "$root\docker-dozerdb-publish\2026.04.1\ubuntu\dozerdb\build-remediate"
tar -czf "..\dozerdb-2026.04.1-unix.tar.gz" "dozerdb-2026.04.1"
```

Then compute checksum:

```powershell
Set-Location "d:\GIT\RNTG-DATA\DB_BI\nsd\CodeScope\dozer\docker-dozerdb-publish\2026.04.1\ubuntu\dozerdb"
(Get-FileHash ".\dozerdb-2026.04.1-unix.tar.gz" -Algorithm SHA256).Hash.ToLower()
```

Update `NEO4J_SHA256` in Dockerfiles if the tarball changed, and keep `release-manifest.yaml` (`local_tarball_sha256`) in sync.

## 7) Build Docker image locally

### 7.1 Ubuntu 24.04 variant (self-contained)

```powershell
Set-Location "d:\GIT\RNTG-DATA\DB_BI\nsd\CodeScope\dozer\docker-dozerdb-publish"
docker buildx build --no-cache `
  --tag "boikovsa/dozerdb:2026.04.1-ubuntu" `
  "2026.04.1/ubuntu/dozerdb"
```

If you host tarball locally, keep `NEO4J_URI` default (`http://host.docker.internal:8765/...`) and serve files from the tarball directory:

```powershell
python -m http.server 8765
```

## 8) Run Trivy scan before publish

```powershell
Set-Location "d:\GIT\RNTG-DATA\DB_BI\nsd\CodeScope\dozer\docker-dozerdb-publish"
trivy image --output "trivy-report-ubuntu.txt" "boikovsa/dozerdb:2026.04.1-ubuntu"
```

## 9) Publish to Docker Hub

Login once:

```powershell
docker login
```

### 9.1 Publish Ubuntu image

```powershell
Set-Location "d:\GIT\RNTG-DATA\DB_BI\nsd\CodeScope\dozer\docker-dozerdb-publish"
docker buildx build --no-cache --push `
  --tag "boikovsa/dozerdb:2026.04.1-ubuntu" `
  "2026.04.1/ubuntu/dozerdb"
```

## 10) Verify published image

```powershell
docker pull "boikovsa/dozerdb:2026.04.1-ubuntu"
docker run --rm "boikovsa/dozerdb:2026.04.1-ubuntu" neo4j --version
```

## 11) Common issues and fixes

- `No such image` on `docker tag`  
  Build first or use the exact existing local tag from `docker images`.

- `COPY ... no such file or directory` during Docker build  
  This is usually build-context mismatch.  
  For Ubuntu variant use context: `"2026.04.1/ubuntu/dozerdb"`.

- `sha256sum ... FAILED` in Docker build  
  Tarball content does not match `NEO4J_SHA256`; recompute hash and update Dockerfile.

- Maven cannot resolve `org.neo4j:*:2026.03.0`  
  Run Neo4j local install step first (`mvn -N ... install` and full `mvn ... install` in `neo4j`).

- Yarn lockfile error (`--frozen-lockfile`)  
  Run plain `yarn install` in `dozerdb-browser` and rebuild.


