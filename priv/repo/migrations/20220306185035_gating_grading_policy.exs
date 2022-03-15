defmodule Oli.Repo.Migrations.GatingGradingPolicy do
  use Ecto.Migration
  import Ecto.Query, warn: false

  def change do
    alter table(:gating_conditions) do
      add :graded_resource_policy, :string, default: "allows_review", null: false
    end

    flush()

    from("gating_conditions")
    |> Oli.Repo.update_all(set: [graded_resource_policy: "allows_review"])
  end
end
