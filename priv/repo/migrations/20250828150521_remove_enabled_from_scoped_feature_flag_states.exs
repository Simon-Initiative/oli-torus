defmodule Oli.Repo.Migrations.RemoveEnabledFromScopedFeatureFlagStates do
  use Ecto.Migration

  def change do
    alter table(:scoped_feature_flag_states) do
      remove :enabled, :boolean
    end
  end
end
