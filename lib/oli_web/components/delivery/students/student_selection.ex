defmodule OliWeb.Components.Delivery.Students.StudentSelection do
  @moduledoc """
  Pure, side-effect-free row-selection logic shared across the student tables/tiles that let an
  instructor select students by checkbox and email the selection.

  Selection is represented as a plain list of student ids (not a `MapSet`), matching how the
  callers already thread selection state through LiveView assigns and compare it in templates
  (`student_id in selected_ids`).
  """

  @type id :: term()

  @doc "Toggles `id` in `selected_ids`: removes it if present, adds it if absent."
  @spec toggle([id], id) :: [id]
  def toggle(selected_ids, id) do
    if id in selected_ids do
      List.delete(selected_ids, id)
    else
      [id | selected_ids]
    end
  end

  @doc """
  Toggles whether every id in `all_ids` is selected: if all are already selected, deselects
  them; otherwise selects whichever of `all_ids` aren't already selected. Ids in `selected_ids`
  that aren't in `all_ids` (e.g. selections from a different filter/page) are left untouched.
  """
  @spec toggle_all([id], [id]) :: [id]
  def toggle_all(all_ids, selected_ids) do
    all_id_set = MapSet.new(all_ids)
    selected_id_set = MapSet.new(selected_ids)

    if all_ids != [] and MapSet.subset?(all_id_set, selected_id_set) do
      Enum.reject(selected_ids, &MapSet.member?(all_id_set, &1))
    else
      selected_ids ++ Enum.reject(all_ids, &MapSet.member?(selected_id_set, &1))
    end
  end

  @doc """
  Comma-separated, de-duplicated emails for the students in `students` whose id is in
  `selected_ids`. Students without a usable email are silently skipped.
  """
  @spec selected_emails([map()], [id]) :: String.t()
  def selected_emails(students, selected_ids) do
    students
    |> selected(selected_ids)
    |> Enum.map(&Map.get(&1, :email))
    |> Oli.Utils.normalize_and_join_strings(", ", unique: true)
  end

  @doc """
  Shapes selected students into the recipient maps `DraftEmailModal` consumes.

  Keeps ALL selected students -- including those without an email -- so the modal can split
  valid recipients from excluded ones and name the excluded students. `name_fn` resolves each
  student's display name (the source field differs per caller, e.g. `:full_name` vs a composed
  name).
  """
  @spec recipients([map()], [id], (map() -> String.t())) :: [map()]
  def recipients(students, selected_ids, name_fn) when is_function(name_fn, 1) do
    students
    |> selected(selected_ids)
    |> Enum.map(fn student ->
      %{
        id: student.id,
        email: Map.get(student, :email),
        given_name: Map.get(student, :given_name),
        family_name: Map.get(student, :family_name),
        display_name: name_fn.(student)
      }
    end)
  end

  defp selected(students, selected_ids) do
    selected_id_set = MapSet.new(selected_ids)
    Enum.filter(students, &MapSet.member?(selected_id_set, &1.id))
  end
end
