defmodule Oli.Repo.Migrations.Lti1p3Lib do
  use Ecto.Migration

  def change do
    rename table(:nonces), to: table(:lti_1p3_nonces)

    drop unique_index(:lti_1p3_params, [:key])

    rename table(:lti_1p3_params), :key, to: :sub
    rename table(:lti_1p3_params), :data, to: :params

    create unique_index(:lti_1p3_params, [:sub])
  end
end
