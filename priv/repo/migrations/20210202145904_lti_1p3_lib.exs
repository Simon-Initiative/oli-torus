defmodule Oli.Repo.Migrations.Lti1p3Lib do
  use Ecto.Migration

  def change do
    rename table(:nonces), to: table(:lti_1p3_nonces)
  end
end
