defmodule Oli.Repo.Migrations.CreateMcpBearerTokenUsage do
  use Ecto.Migration

  def change do
    create table(:mcp_bearer_token_usages) do
      add :bearer_token_id, references(:mcp_bearer_tokens, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :tool_name, :string
      add :resource_uri, :string
      add :occurred_at, :utc_datetime, null: false
      add :request_id, :string
      add :status, :string
    end

    create index(:mcp_bearer_token_usages, [:bearer_token_id])
    create index(:mcp_bearer_token_usages, [:occurred_at])
    create index(:mcp_bearer_token_usages, [:event_type])
    create index(:mcp_bearer_token_usages, [:bearer_token_id, :occurred_at])
  end
end
