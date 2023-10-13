defmodule Oli.Repo.Migrations.AddBlueprintTable do
  alias Oli.Repo
  use Ecto.Migration
  require Logger

  def change do
    create table(:blueprints) do
      add(:name, :string, size: 64, null: false)
      add(:description, :string, null: false)
      add(:content, :map, null: false)
      add(:icon, :string, null: false)
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

    insert_statement =
      "insert into blueprints (name, description, content, icon, inserted_at, updated_at)
       values ('Theorem', 'A theorem is a statement that can be proven true.', $1, 'rate_review', now(), now());"

    {:ok, _} = Ecto.Adapters.SQL.query(Repo, insert_statement, [theorem_blueprint])
  end
end
