defmodule Oli.Delivery.ActivityProvider do
  alias Oli.Activities.Realizer
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Activities.Realizer.Selection
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Revision

  @doc """
  Realizes and resolves activities.
  """
  def provide(%Revision{content: %{"model" => model} = content} = revision, %Source{} = source) do
    # Make a pass through the revision content model to gather all statically referenced activity ids
    # and to fulfill all activity bank selections
    {errors, activities, model} =
      Enum.reduce(model, {[], [], []}, fn e, {errors, activities, model} ->
        case e["type"] do
          "activity-reference" ->
            {errors, [e["activity_id"] | activities], [e | model]}

          "selection" ->
            {:ok, %Selection{} = selection} = Selection.parse(e)

            case Selection.fulfill(selection, source) do
              {:ok, %Result{} = result} ->
                {errors, Enum.reverse(result.rows) ++ activities,
                 replace_selection(e, result.rows)}

              {:partial, %Result{} = result} ->
                error =
                  "Selection failed to fulfill completely: Section #{source.section_slug}, Resource #{revision.resource_id}, Error: #{e}"

                {[error | errors], Enum.reverse(result.rows) ++ activities,
                 replace_selection(e, result.rows)}

              e ->
                error =
                  "Selection failed to fulfill: Section #{source.section_slug}, Resource #{revision.resource_id}, Error: #{e}"

                {[error | errors], activities, model}
            end
        end
      end)

    # At this point "activities" is a list of activity_ids and revisions, we must resolve the revisions
    # of all the activity_ids, while preserving the order in which they appear in the content

    case Realizer.realize(revision) do
      [] -> []
      ids -> DeliveryResolver.from_resource_id(section_slug, ids)
    end
  end

  defp replace_selection(selection_element, revisions) do
    Enum.map(revisions, fn r ->
      %{
        "type" => "activity-reference",
        "id" => Oli.Utils.uuid(),
        "activity_id" => r.resource_id,
        "purpose" => selection_element["purpose"],
        "children" => [],
        "source-selection" => selection_element["id"]
      }
    end)
  end
end
