defmodule Oli.Repo.Migrations.AddAdminActAsUserFeatureFlag do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO feature_states (label, state)
    VALUES ('admin-act-as-user', 'disabled')
    ON CONFLICT (label) DO NOTHING
    """)
  end

  def down do
    execute("DELETE FROM feature_states WHERE label = 'admin-act-as-user'")
  end
end
