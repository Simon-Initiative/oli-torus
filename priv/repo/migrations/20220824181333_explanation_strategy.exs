defmodule Oli.Repo.Migrations.ExplanationStrategy do
  use Ecto.Migration

  def change do
    # create table(:explanation_strategies) do
    #   add :type, :string, default: "after_max_resource_attempts_exhausted", null: false
    #   add :set_num_attempts, :integer
    #   add :revision_id, references(:revisions, on_delete: :delete_all)

    #   timestamps()
    # end

    alter table(:revisions) do
      add :explanation_strategy, :map
    end
  end
end
