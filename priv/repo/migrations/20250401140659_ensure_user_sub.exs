defmodule Oli.Repo.Migrations.EnsureUserUniqueSub do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    # Generate unique subs for users with nil sub
    execute("""
      UPDATE users
      SET sub = gen_random_uuid()
      WHERE sub IS NULL
    """)

    # Ensure the sub field is not null
    alter table(:users) do
      modify :sub, :string, null: false
    end
  end

  def down do
    # Allow null values in the sub field
    alter table(:users) do
      modify :sub, :string, null: true
    end
  end
end
