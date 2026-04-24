FROM ubuntu:24.04 AS su_exec_builder
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates gcc git libc6-dev make \
    && git clone https://github.com/ncopa/su-exec.git /tmp/su-exec \
    && cd /tmp/su-exec \
    && git checkout 4c3bb42b093f14da70d8ab924b487ccfbb1397af \
    && echo d6c40440609a23483f12eb6295b5191e94baf08298a856bab6e15b10c3b82891 su-exec.c | sha256sum -c \
    && echo 2a87af245eb125aca9305a0b1025525ac80825590800f047419dc57bba36b334 Makefile | sha256sum -c \
    && make \
    && install -m 0755 su-exec /usr/local/bin/su-exec \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/su-exec

FROM ubuntu:24.04
ENV JAVA_HOME=/opt/java/openjdk
COPY --from=eclipse-temurin:21 $JAVA_HOME $JAVA_HOME
ENV PATH="${JAVA_HOME}/bin:${PATH}" \
    NEO4J_SHA256=1d76394e2716c51acff6c2e2e05714354a2c68bc6472e27994e034efe71bbb24 \
    NEO4J_TARBALL=dozerdb-2026.04.1-unix.tar.gz \
    NEO4J_EDITION=community \
    NEO4J_HOME="/var/lib/neo4j" \
    APOC_VERSION=2026.03.0 \
    LANG=C.UTF-8
ARG NEO4J_URI=http://host.docker.internal:8765/dozerdb-2026.04.1-unix.tar.gz

RUN groupadd --gid 7474 --system neo4j \
    && useradd --uid 7474 --system --no-create-home --home-dir "${NEO4J_HOME}" --gid neo4j neo4j

# Self-contained local startup assets for Ubuntu variant.
COPY ./local-package/* /startup/
COPY --from=su_exec_builder /usr/local/bin/su-exec /usr/bin/su-exec

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates procps tini wget \
    && chmod +x /startup/docker-entrypoint.sh /startup/neo4j-admin-report.sh \
    && wget --quiet --timeout=60 --tries=20 --retry-connrefused "${NEO4J_URI}" \
    && echo "${NEO4J_SHA256}  ${NEO4J_TARBALL}" | sha256sum -c --strict --quiet \
    && tar --extract --file ${NEO4J_TARBALL} --directory /var/lib \
    && mv /var/lib/dozerdb-* "${NEO4J_HOME}" \
    && wget --quiet --timeout=60 --tries=20 --retry-connrefused "https://github.com/neo4j/apoc/releases/download/${APOC_VERSION}/apoc-${APOC_VERSION}-core.jar" \
    && mv "apoc-${APOC_VERSION}-core.jar" "${NEO4J_HOME}/plugins/" \
    && rm ${NEO4J_TARBALL} \
    && sed -i 's/Package Type:.*/Package Type: docker ubuntu-24.04/' $NEO4J_HOME/packaging_info \
    && mv /startup/neo4j-admin-report.sh "${NEO4J_HOME}"/bin/neo4j-admin-report \
    && mv "${NEO4J_HOME}"/data /data \
    && mv "${NEO4J_HOME}"/logs /logs \
    && chown -R neo4j:neo4j /data \
    && chmod -R 777 /data \
    && chown -R neo4j:neo4j /logs \
    && chmod -R 777 /logs \
    && chown -R neo4j:neo4j "${NEO4J_HOME}" \
    && chmod -R 777 "${NEO4J_HOME}" \
    && chmod -R 755 "${NEO4J_HOME}/bin" \
    && ln -s /data "${NEO4J_HOME}"/data \
    && ln -s /logs "${NEO4J_HOME}"/logs \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="${NEO4J_HOME}"/bin:$PATH

WORKDIR "${NEO4J_HOME}"

VOLUME /data /logs

EXPOSE 7474 7473 7687

ENTRYPOINT ["tini", "-g", "--", "/startup/docker-entrypoint.sh"]
CMD ["neo4j"]
