defmodule Oli.Repo.Migrations.AddHintsToSnapshots do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Repo

  def up do
    alter table(:snapshots) do
      add :hints_content, {:array, :map}, default: [], null: false
    end

    flush()

    results =
      from(s in "snapshots",
        join: r in "revisions",
        on: r.id == s.revision_id,
        select: %{
          id: s.id,
          part_id: s.part_id,
          parts: fragment("jsonb_path_query_array(?, '$.authoring.parts[*]')", r.content)
        }
      )
      |> Repo.all()
      |> Enum.each(fn %{id: id, part_id: part_id, parts: parts} ->
        hints =
          case Enum.filter(parts, fn p -> p["part_id"] == part_id end) do
            [] -> []
            part -> Map.get(part, "hints", [])
          end

        execute """
                UPDATE snapshots
                SET "hints_content" = $1
                WHERE snapshots.id = $2
                """,
                [hints, id]
      end)
  end

  def down do
    alter table(:snapshots) do
      remove :hints_content
    end
  end
end
