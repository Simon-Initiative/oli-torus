defmodule Oli.Snapshots.SnapshotSeeder do

  alias Oli.Seeder
  alias Oli.Activities.Model.Part

  defp get_csv_headers(path) do
    [ok: headers] = path
    |> File.stream!
    |> CSV.decode
    |> Enum.take(1)

    headers
    |> Enum.map(&String.to_atom/1)
  end

  defp get_csv_snapshots(path) do
    path
    |> File.stream!
    |> CSV.decode(headers: get_csv_headers(path))
    |> Enum.drop(1)
  end

  defp parse_row({:ok, snapshot}) do
    %{
      activity_tag: String.to_atom(snapshot.activity_tag),
      activity_type_id: elem(Integer.parse(snapshot.activity_type_id), 0),
      attempt_number: elem(Integer.parse(snapshot.attempt_number), 0),
      correct: to_bool(snapshot.correct),
      graded: to_bool(snapshot.graded),
      hints: elem(Integer.parse(snapshot.hints), 0),
      objective_tag: String.to_atom(snapshot.objective_tag),
      out_of: elem(Integer.parse(snapshot.out_of), 0),
      part_attempt_tag: String.to_atom(snapshot.part_attempt_tag),
      part_attempt_number: elem(Integer.parse(snapshot.part_attempt_number), 0),
      part_id: snapshot.part_id,
      resource_attempt_number: elem(Integer.parse(snapshot.resource_attempt_number), 0),
      resource_tag: String.to_atom(snapshot.resource_tag),
      score: elem(Integer.parse(snapshot.score), 0),
      section_tag: String.to_atom(snapshot.section_tag),
      user_tag: String.to_atom(snapshot.user_tag)
    }
  end

  defp create_if_necessary(map, key, creation_fn) do
    case map[key] do
      nil -> creation_fn.(map)
      _ -> map
    end
  end

  defp to_bool("TRUE"), do: true
  defp to_bool("FALSE"), do: false

  def setup_csv(map, path) do

    get_csv_snapshots(path)
    |> Enum.map(&parse_row/1)
    |> Enum.reduce(map, fn (%{
      activity_tag: activity_tag,
      objective_tag: objective_tag,
      part_attempt_tag: _part_attempt_tag,
      resource_tag: resource_tag,
      section_tag: _section_tag,
      user_tag: user_tag } = snapshot, map) ->

      part_attempt_tag = Ecto.UUID.generate()

      # Create linkages if necessary. These are not used for analytics queries but are
      # required to satisfy database constraints
      map = map
      |> create_if_necessary(user_tag,
        fn map -> Seeder.add_user(map, %{}, user_tag) end)
      |> create_if_necessary(resource_tag,
        fn map -> Seeder.add_page(map, %{title: Atom.to_string(resource_tag)}, resource_tag) end)
      |> create_if_necessary(objective_tag,
        fn map -> Seeder.add_objective(map, Atom.to_string(objective_tag), objective_tag) end)
      |> create_if_necessary(activity_tag,
        fn map -> Seeder.add_activity(map, %{title: Atom.to_string(activity_tag)}, activity_tag) end)
      |> create_if_necessary(:ra1,
        fn map -> Seeder.create_resource_attempt(map, %{attempt_number: 1}, user_tag, resource_tag, :attempt1) end)
      |> create_if_necessary(:aa1,
        fn map -> Seeder.create_activity_attempt(map, %{attempt_number: 1, transformed_model: %{}}, activity_tag, :attempt1, :activity_attempt1) end)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt1, part_attempt_tag)

      # Create the activity snapshot using the new map with required linkages
      map
      |> Seeder.add_activity_snapshot(Map.merge(snapshot, %{
        resource_id: map[resource_tag].resource.id,
        activity_id: map[activity_tag].resource.id,
        part_attempt_id: map[part_attempt_tag].id,
        user_id: map[user_tag].id,
        section_id: map.section.id,
        objective_id: map[objective_tag].resource.id,
        objective_revision_id: map[objective_tag].revision.id,
        revision_id: map[activity_tag].revision.id,
      }), Ecto.UUID.generate())
      end)
  end
end
