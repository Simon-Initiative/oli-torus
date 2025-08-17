defmodule Oli.Repo.Migrations.CreateMcpBearerTokens do
  use Ecto.Migration

  def change do
    create table(:mcp_bearer_tokens) do
      add :author_id, references(:authors, on_delete: :delete_all), null: false
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :hash, :binary, null: false
      add :hint, :string
      add :status, :string, default: "enabled", null: false
      add :last_used_at, :utc_datetime

      timestamps()
    end

    create unique_index(:mcp_bearer_tokens, [:author_id, :project_id])
    create index(:mcp_bearer_tokens, [:hash])
    create index(:mcp_bearer_tokens, [:status])
  end
end
