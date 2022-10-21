defmodule Oli.Repo.Migrations.AddBlueprintTable do
  alias Oli.Repo
  alias Oli.Authoring.Editing.Blueprint
  use Ecto.Migration
  require Logger

  def change do
    create table(:blueprints) do
      add :name, :string, size: 64, null: false
      add :description, :string, null: false
      add :content, :map, null: false
      add :icon, :string, null: false
      timestamps(type: :timestamptz)
    end

    execute(&insert_theorem/0, &noop/0)
  end

  def noop(), do: :ok

  def insert_theorem() do
    flush()

    theorem_blueprint =
      Jason.decode!(
        "{\"blueprint\":[{\"id\":\"\",\"children\":[{\"text\":\"Theorem Title\"}],\"type\":\"h4\"},{\"id\":\"\",\"children\":[{\"text\":\"Statement\"}],\"type\":\"h5\"},{\"id\":\"\",\"children\":[{\"text\":\"Enter a statement here\"}],\"type\":\"p\"},{\"id\":\"\",\"children\":[{\"text\":\"Proof\"}],\"type\":\"h5\"},{\"id\":\"\",\"children\":[{\"text\":\"Enter the proof here\"}],\"type\":\"p\"}]}"
      )

    changeset =
      Blueprint.changeset(%Blueprint{}, %{
        name: "Theorem",
        description: "A theorem is a statement that can be proven true.",
        content: theorem_blueprint,
        icon: "rate_review"
      })

    {:ok, _} = Repo.insert(changeset)
  end
end
