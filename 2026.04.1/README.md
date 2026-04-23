# DozerDB 2026.04.1 (trixie)

This release folder packages the `2026.04.1` plugin artifacts into a `trixie`-based image.

## Build Locally (using local tarball)

1. Ensure `dozerdb-2026.04.1-unix.tar.gz` exists in `2026.04.1/trixie/dozerdb/`.
2. Serve that folder:

```bash
python -m http.server 8765
```

3. Build image:

```bash
docker build --platform linux/amd64 \
  --build-arg NEO4J_URI="http://host.docker.internal:8765/dozerdb-2026.04.1-unix.tar.gz" \
  -t dozerdb:2026.04.1-trixie-local \
  "2026.04.1/trixie/dozerdb"
```

## Publish Build (fork release asset)

The default Dockerfile URI already points to the fork release path:

- `https://github.com/sergeiboikov/docker-dozerdb-publish/releases/download/2026.04.1/dozerdb-2026.04.1-unix.tar.gz`

Build and push multi-arch tags:

```bash
docker buildx build \
  --tag "boikovsa/dozerdb:2026.04.1-trixie" \
  --tag "boikovsa/dozerdb:2026.04.1" \
  --tag "boikovsa/dozerdb:latest" \
  "2026.04.1/trixie/dozerdb" \
  --push
```

## Pinned local tarball checksum

- `dozerdb-2026.04.1-unix.tar.gz`: `b24580fa94701650c81e0f912bebc48b1200838be66391934acd266a92082dd4`
