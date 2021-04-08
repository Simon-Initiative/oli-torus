defmodule Oli.Repo.Migrations.AddFeaturesTable do
  use Ecto.Migration

  def change do
    create table(:feature_states) do
      add :state, :string
      timestamps(type: :timestamptz)
    end
  end
end
