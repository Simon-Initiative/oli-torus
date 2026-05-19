# AGENTS.md

This file provides guidance to AI agents working in `priv/clickhouse/`.

## Scope

Apply these instructions for ClickHouse schema, migration, and related operational files in this subtree.

## ClickHouse Migrations

1. Place ClickHouse SQL migrations in `priv/clickhouse/migrations/` using goose `-- +goose Up` / `-- +goose Down` sections
2. Keep each ClickHouse SQL statement as its own standalone statement terminated by `;`
3. Do not wrap multiple ClickHouse statements in `-- +goose StatementBegin` / `-- +goose StatementEnd`
4. Reason: goose sends a `StatementBegin` block as a single query, and ClickHouse rejects multi-statement queries with `Syntax error (Multi-statements are not allowed)`
5. When a migration needs several `ALTER TABLE` operations, list them as separate statements so goose executes them one at a time
6. Prefer explicit, reversible `Up` and `Down` sections when ClickHouse supports rollback operations for the change
7. For additive or destructive schema operations that may be retried after a partial failure, prefer `IF NOT EXISTS` and `IF EXISTS` where ClickHouse supports them

## Table Design Notes

1. Read the existing table definition before changing schema so new migrations stay aligned with current column order, defaults, partitioning, and indexes
2. Do not assume ClickHouse key columns can be altered in place. Columns used by `PARTITION BY`, `ORDER BY`, or the primary key are high-risk and may reject `MODIFY COLUMN`
3. Be careful with non-null to nullable and nullable to non-null changes because existing data can make reverse migrations fail
4. Treat destructive changes such as `DROP COLUMN` or incompatible type changes as high-risk and call them out clearly in your summary

## Verification

1. After editing a ClickHouse migration, re-read the final SQL file to confirm goose annotations and statement boundaries are correct
2. Confirm whether any changed column participates in `PARTITION BY`, `ORDER BY`, or key expressions before using `MODIFY COLUMN`
3. If you change schema that affects ingest or queries, also inspect the corresponding application code that reads from or writes to the modified columns
