FROM postgres:17

USER root

COPY ./backup.sh /usr/local/bin/backup.sh

RUN chmod +x /usr/local/bin/backup.sh \
  && mkdir -p /backups \
  && chown -R postgres:postgres /backups

ENV BACKUP_RETENTION_DAYS=7 \
    BACKUP_DIR=/backups

USER postgres

VOLUME ["/backups"]

ENTRYPOINT ["/bin/bash", "/usr/local/bin/backup.sh"]
