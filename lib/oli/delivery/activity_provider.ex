defmodule Oli.Delivery.ActivityProvider do
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Activities.Realizer.Selection
  alias Oli.Resources.Revision
  alias Oli.Resources.PageContent
  alias Oli.Delivery.ActivityProvider.Result, as: ProviderResult
  alias Oli.Utils.BibUtils

  @doc """
  Realizes and resolves activities in a page.

  For advanced delivery pages this impl finds all activity-reference instances from within the entire
  nested tree of the content model.  For basic delivery, we only need to look at the top-level model
  collection, but do need to look for selections as well as static activity-reference instances.

  Activities are realized in different ways, depending on the type of reference. First, a static
  reference to an activity (via "activity-reference") is simply resolved to the correct published
  resource. A second type of reference is a selection from the activity bank (via "selection" element).
  These are realized by fulfilling the selection (i.e. drawing the required number of activities randomly
  from the bank according to defined criteria).

  Activity realization can change the content of the page revision. This is true currently only for
  selections.  The selection element from within the page must be replaced by static activity references
  (which later then drive rendering).

  Returns a %Oli.Delivery.ActivityProvider.Result{}, which contains a list of any errors, the provided
  activity revisions, a MapSet of those revision resource ids that are to be unscored
  activities and the transformed page model.
  """
  def provide(
        %Revision{content: %{"advancedDelivery" => true} = content},
        %Source{} = source,
        resolver
      ) do
    refs =
      PageContent.flat_filter(content, fn e ->
        case Map.get(e, "type", nil) do
          nil -> false
          "activity-reference" -> true
          _ -> false
        end
      end)

    unscored =
      refs
      |> Enum.filter(fn ref ->
        case Map.get(ref, "custom", %{}) do
          %{"isLayer" => true} -> true
          %{"isBank" => true} -> true
          _ -> false
        end
      end)
      |> Enum.map(fn %{"activity_id" => id} -> id end)
      |> MapSet.new()

    activity_ids =
      refs
      |> Enum.map(fn %{"activity_id" => id} -> id end)

    revisions = resolver.from_resource_id(source.section_slug, activity_ids)

    bib_revisions =
      BibUtils.assemble_bib_entries(
        content,
        revisions,
        fn r -> Map.get(r.content, "bibrefs", []) end,
        source.section_slug,
        resolver
      )
      |> Enum.with_index(1)
      |> Enum.map(fn {revision, ordinal} -> BibUtils.serialize_revision(revision, ordinal) end)

    %ProviderResult{
      errors: [],
      revisions: revisions,
      bib_revisions: bib_revisions,
      transformed_content: content,
      unscored: unscored
    }
  end

  def provide(
        %Revision{content: %{"model" => model} = content},
        %Source{} = source,
        resolver
      ) do
    {errors, activities, model, _} = fulfill(model, source)

    only_revisions =
      resolve_activity_ids(source.section_slug, activities, resolver) |> Enum.reverse()

    bib_revisions =
      BibUtils.assemble_bib_entries(
        content,
        only_revisions,
        fn r -> Map.get(r.content, "bibrefs", []) end,
        source.section_slug,
        resolver
      )
      |> Enum.with_index(1)
      |> Enum.map(fn {revision, ordinal} -> BibUtils.serialize_revision(revision, ordinal) end)

    %ProviderResult{
      errors: errors,
      revisions: only_revisions,
      bib_revisions: bib_revisions,
      transformed_content: Map.put(content, "model", Enum.reverse(model)),
      unscored: MapSet.new()
    }
  end

  # Make a pass through the revision content model to gather all statically referenced activity ids
  # and to fulfill all activity bank selections.
  #
  # In order to prevent multiple selections on the page potentially realizing the same activity more
  # than once, we update the blacklisted activity ids within the source as we proceed through the
  # collection of activity references.
  #
  # Note: To optimize performance we prepend all activity ids and revisions as we pass through, and
  # then do a final Enum.reverse to restore the correct order.  We do the same thing for the elements
  # within the transformed page model.
  defp fulfill(model, %Source{} = source) do
    Enum.reduce(model, {[], [], [], source}, fn e, {errors, activities, model, source} ->
      case e["type"] do
        "activity-reference" ->
          {errors, [e["activity_id"] | activities], [e | model], source}

        "selection" ->
          {:ok, %Selection{} = selection} = Selection.parse(e)

          case Selection.fulfill(selection, source) do
            {:ok, %Result{} = result} ->
              reversed = Enum.reverse(result.rows)

              {errors, reversed ++ activities, replace_selection(e, reversed) ++ model,
               merge_blacklist(source, result.rows)}

            {:partial, %Result{} = result} ->
              missing = selection.count - result.rowCount

              error = "Selection failed to fulfill completely with #{missing} missing activities"

              reversed = Enum.reverse(result.rows)

              {[error | errors], reversed ++ activities, replace_selection(e, reversed) ++ model,
               merge_blacklist(source, result.rows)}

            e ->
              error = "Selection failed to fulfill with error: #{e}"
              {[error | errors], activities, model, source}
          end

        "group" ->
          {c_errors, c_activities, c_model, source} = fulfill(e["children"], source)
          e = %{e | "children" => Enum.reverse(c_model)}

          {c_errors ++ errors, c_activities ++ activities, [e | model], source}

        _ ->
          {errors, activities, [e | model], source}
      end
    end)
  end

  # At this point "activities" is a list whose entries are either activity_ids or revisions, now
  # we must resolve the revisions of all the entires that are simply activity ids,
  # replacing them in the list with the resolved revision.

  # Returns a list of revisions.
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

  # Takes a JSON selection element as a map and returns a list of activity-reference
  # JSON elements that represent which activities fulfilled the selection.
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

  # Merge the blacklisted activity ids of the given source with the resource ids of the
  # given list of revisions
  defp merge_blacklist(%Source{blacklisted_activity_ids: ids} = source, revisions) do
    %{
      source
      | blacklisted_activity_ids: Enum.map(revisions, fn r -> r.resource_id end) ++ ids
    }
  end

end
