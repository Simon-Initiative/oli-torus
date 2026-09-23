defmodule Oli.Repo.Migrations.AddSecureAssessmentScopeToUsersTokens do
  use Ecto.Migration

  def up do
    alter table(:users_tokens) do
      add :secure_section_id, references(:sections, on_delete: :delete_all)
      add :secure_resource_id, references(:resources, on_delete: :delete_all)
    end

    create index(:users_tokens, [:secure_section_id])
    create index(:users_tokens, [:secure_resource_id])

    create constraint(:users_tokens, :secure_session_scope,
             check:
               "(secure_section_id IS NULL AND secure_resource_id IS NULL) OR (context = 'session' AND secure_section_id IS NOT NULL AND secure_resource_id IS NOT NULL)"
           )
  end

  def down do
    execute "DELETE FROM users_tokens WHERE secure_section_id IS NOT NULL OR secure_resource_id IS NOT NULL"
    drop constraint(:users_tokens, :secure_session_scope)
    drop index(:users_tokens, [:secure_resource_id])
    drop index(:users_tokens, [:secure_section_id])

    alter table(:users_tokens) do
      remove :secure_resource_id
      remove :secure_section_id
    end
  end
end
