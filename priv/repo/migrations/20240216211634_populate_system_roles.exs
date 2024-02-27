defmodule Oli.Repo.Migrations.PopulateSystemRoles do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE system_roles SET type = 'system_admin' WHERE id = 2;
    """)

    execute("""
    INSERT INTO system_roles (id, type, inserted_at, updated_at) VALUES
    (3, 'account_admin', now(), now()),
    (4, 'content_admin', now(), now())
    ON CONFLICT(id)
    DO UPDATE SET
      type = EXCLUDED.type,
      updated_at = EXCLUDED.updated_at;
    """)
  end

  def down do
    execute("""
      UPDATE authors
      SET system_role_id = (
        SELECT id FROM system_roles WHERE type = 'system_admin'
      )
      WHERE system_role_id IN (
        SELECT id FROM system_roles WHERE type IN ('account_admin', 'content_admin')
      );
    """)

    execute("""
    UPDATE system_roles SET type = 'admin' WHERE id = 2;
    """)

    execute("""
    DELETE FROM system_roles WHERE type IN ('account_admin', 'content_admin');
    """)
  end
end
