FROM haproxy:3.3.6

USER root

RUN mkdir -p /certs
COPY combined.pem /certs/combined.pem

COPY haproxy_minio_docker.cfg /usr/local/etc/haproxy/haproxy.minio.cfg.template
COPY haproxy_docker.cfg /usr/local/etc/haproxy/haproxy.origin.cfg.template
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER haproxy

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
