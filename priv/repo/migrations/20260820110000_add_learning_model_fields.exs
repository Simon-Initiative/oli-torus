defmodule Oli.Repo.Migrations.AddLearningModelFields do
  use Ecto.Migration

  def up do
    execute("SET LOCAL lock_timeout = '5s'")

    alter table(:projects) do
      add :learning_model_version, :string, default: "naive"
    end

    alter table(:sections) do
      add :learning_model_version, :string, default: "naive"
    end

    execute(
      "UPDATE projects SET learning_model_version = 'naive' WHERE learning_model_version IS NULL"
    )

    execute(
      "UPDATE sections SET learning_model_version = 'naive' WHERE learning_model_version IS NULL"
    )

    alter table(:projects) do
      modify :learning_model_version, :string, null: false, default: "naive"
    end

    alter table(:sections) do
      modify :learning_model_version, :string, null: false, default: "naive"
    end

    create constraint(:projects, :projects_learning_model_version_check,
             check: "learning_model_version IN ('naive', 'lkt_aoa')"
           )

    create constraint(:sections, :sections_learning_model_version_check,
             check: "learning_model_version IN ('naive', 'lkt_aoa')"
           )

    alter table(:revisions) do
      add :learning_model_parameters, :map
    end
  end

  def down do
    execute("SET LOCAL lock_timeout = '5s'")

    drop constraint(:sections, :sections_learning_model_version_check)
    drop constraint(:projects, :projects_learning_model_version_check)

    alter table(:revisions) do
      remove :learning_model_parameters
    end

    alter table(:sections) do
      remove :learning_model_version
    end

    alter table(:projects) do
      remove :learning_model_version
    end
  end
end
