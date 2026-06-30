# DevOps Operations Reference

This directory contains repository-managed DevOps configuration for OLI Torus.

Kubernetes-based deployment manifests have been moved to a private GitOps repository.

## Structure

- `clickhouse-backup/clickhouse-backup.sh` - Backup entrypoint used by systemd for scheduled ClickHouse backups.
- `clickhouse-backup/systemd/clickhouse-backup.service` - One-shot service unit that runs the installed backup script.
- `clickhouse-backup/systemd/clickhouse-backup.timer` - Daily timer that triggers the backup service at midnight UTC.

## ClickHouse Backup

The ClickHouse backup files are source artifacts for the ClickHouse host. Install them onto the target host and adjust paths as needed for that environment.

The committed service file expects the backup script to be installed at:

```bash
/opt/scripts/clickhouse-backup.sh
```

After installing or updating the systemd unit files, reload systemd and enable the timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now clickhouse-backup.timer
```

To run a backup immediately without waiting for the timer:

```bash
sudo systemctl start clickhouse-backup.service
```

To inspect timer state and recent backup logs:

```bash
systemctl list-timers clickhouse-backup.timer
journalctl -u clickhouse-backup.service
```
