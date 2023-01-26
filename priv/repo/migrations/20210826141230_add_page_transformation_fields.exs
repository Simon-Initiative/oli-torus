defmodule Oli.Repo.Migrations.AddPageTransformationFields do
  use Ecto.Migration

  def change do
    alter table(:resource_attempts) do
      add :content, :map
      add :errors, {:array, :string}
    end

    flush()

    execute "UPDATE resource_attempts SET content = revisions.content FROM revisions WHERE resource_attempts.revision_id = revisions.id;"

    flush()
  end
end
