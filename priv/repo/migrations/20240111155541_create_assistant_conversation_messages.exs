defmodule Oli.Repo.Migrations.CreateConversationMessages do
  use Ecto.Migration

  def change do
    create table(:conversation_messages) do
      add :role, :string
      add :content, :text
      add :name, :text
      add :token_length, :integer
      add :user_id, references(:users, on_delete: :nothing)
      add :resource_id, references(:resources, on_delete: :nothing)

      timestamps(type: :timestamptz)
    end

    create index(:conversation_messages, [:user_id, :resource_id])
  end
end
