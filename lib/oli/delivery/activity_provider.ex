defmodule Oli.Delivery.ActivityProvider do
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Activities.Realizer.Selection
  alias Oli.Resources.Revision

  @doc """
  Realizes and resolves activities in a page.

  Returns a three element tuple, with the first element being a list of any errors encountered,
  the second being the revisions of all provided activities, and the third being the transformed
  content of the page revision.
  """
  def provide(
        %Revision{content: %{"model" => model} = content},
        %Source{} = source,
        resolver
      ) do
    {errors, activities, model} = fulfill(model, source)

    only_revisions =
      resolve_activity_ids(source.section_slug, activities, resolver) |> Enum.reverse()

    IO.inspect(errors)
    {errors, only_revisions, Map.put(content, "model", model)}
  end

  # Make a pass through the revision content model to gather all statically referenced activity ids
  # and to fulfill all activity bank selections
  defp fulfill(model, %Source{} = source) do
    Enum.reduce(model, {[], [], []}, fn e, {errors, activities, model} ->
      case e["type"] do
        "activity-reference" ->
          {errors, [e["activity_id"] | activities], [e | model]}

        "selection" ->
          {:ok, %Selection{} = selection} = Selection.parse(e)

          case Selection.fulfill(selection, source) do
            {:ok, %Result{} = result} ->
              IO.inspect("success")
              IO.inspect(result.rows)
              {errors, Enum.reverse(result.rows) ++ activities, replace_selection(e, result.rows)}

            {:partial, %Result{} = result} ->
              IO.inspect("missing")
              missing = selection.count - result.rowCount

              error = "Selection failed to fulfill completely with #{missing} missing activities"

              {[error | errors], Enum.reverse(result.rows) ++ activities,
               replace_selection(e, result.rows)}

            e ->
              error = "Selection failed to fulfill with error: #{e}"

              {[error | errors], activities, model}
          end

        _ ->
          {errors, activities, [e | model]}
      end
    end)
  end

  # At this point "activities" is a list of activity_ids and revisions, we must resolve the revisions
  # of all the activity_ids, while preserving their order in which they appear in the content, including
  # the interspersed revisions from fulfilled selections.  Returns a list of revisions (where the original)
  # entries that were ids are replaced by their resolved revisions).
  defp resolve_activity_ids(section_slug, activities, resolver) do
    activity_ids =
      Enum.filter(activities, fn a ->
        case a do
          %Revision{id: _} -> false
          _ -> true
        end
      end)

    map =
      resolver.from_resource_id(section_slug, activity_ids)
      |> Enum.reduce(%{}, fn rev, m -> Map.put(m, rev.resource_id, rev) end)

    Enum.map(activities, fn a ->
      case a do
        %Revision{id: _} -> a
        id -> Map.get(map, id)
      end
    end)
  end

  defp replace_selection(selection_element, revisions) do
    Enum.map(revisions, fn r ->
      %{
        "type" => "activity-reference",
        "id" => Oli.Utils.uuid(),
        "activity_id" => r.resource_id,
        "purpose" => Map.get(selection_element, "purpose", ""),
        "children" => [],
        "source-selection" => selection_element["id"]
      }
    end)
  end
end
