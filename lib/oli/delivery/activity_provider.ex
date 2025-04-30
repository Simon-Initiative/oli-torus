defmodule Oli.Delivery.ActivityProvider do
  alias Oli.Repo
  import Ecto.Query, warn: false

  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.BankEntry
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Activities.Realizer.Selection
  alias Oli.Resources.PageContent
  alias Oli.Delivery.ActivityProvider.Result, as: ProviderResult
  alias Oli.Delivery.ActivityProvider.AttemptPrototype
  alias Oli.Utils.BibUtils
  alias Oli.Resources.ResourceType

  @doc """
  Realizes and resolves activities in a page.

  For advanced delivery pages this impl finds all activity-reference instances from within the entire
  nested tree of the content model.  For basic delivery, we traverse the entire hierarchy of the page
  content, tracking groups and surveys, and processing selections as well as static activity-reference instances.

  Activities are realized in different ways, depending on the type of reference. First, a static
  reference to an activity (via "activity-reference") is simply resolved to the correct published
  resource. A second type of reference is a selection from the activity bank (via "selection" element).
  These are realized by fulfilling the selection (i.e. drawing the required number of activities randomly
  from the bank according to defined criteria).

  Activity realization can change the content of the page revision. This is true currently only for
  selections.  The selection element from within the page must be replaced by static activity references
  (which later then drive rendering).

  Returns a %Oli.Delivery.ActivityProvider.Result{}, which contains a list of any errors, the provided
  activity attempt prototypes, and the transformed page model.

  Parameters for provide are:
  1. The content of the page revision that we are providing activities for
  2. The source through which we provide activities
  3. A list of pre-existing attempt prototypes that constrain the activity realization
  4. The current user
  5. The current section_slug
  5. The resolver to use
  """
  def provide(
        %{"advancedDelivery" => true} = content,
        %Source{} = source,
        _constraining_attempt_prototypes,
        _user,
        _section_slug,
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
      prototypes:
        Enum.map(revisions, fn r ->
          %AttemptPrototype{
            revision: r
          }
        end),
      bib_revisions: bib_revisions,
      transformed_content: content,
      unscored: unscored
    }
  end

  def provide(
        %{"model" => model} = content,
        %Source{} = source,
        constraining_attempt_prototypes,
        user,
        section_slug,
        resolver
      ) do
    %{
      prototypes: prototypes,
      errors: errors
    } = fulfill(model, source, user, section_slug, constraining_attempt_prototypes)

    prototypes_with_revisions =
      resolve_activity_ids(source.section_slug, prototypes, resolver)
      |> Enum.map(fn p -> set_out_of(p) end)

    bib_revisions =
      BibUtils.assemble_bib_entries(
        content,
        Enum.map(prototypes_with_revisions, fn p -> p.revision end),
        fn r -> Map.get(r.content, "bibrefs", []) end,
        source.section_slug,
        resolver
      )
      |> Enum.with_index(1)
      |> Enum.map(fn {revision, ordinal} -> BibUtils.serialize_revision(revision, ordinal) end)

    # See if at least one of the realized prototypes came from an activity selection
    has_selection = Enum.any?(prototypes_with_revisions, fn p -> !is_nil(p.selection_id) end)

    %ProviderResult{
      errors: errors,
      prototypes: prototypes_with_revisions,
      bib_revisions: bib_revisions,
      unscored: MapSet.new(),
      # A slight optimization, we only transform the content if there is at least one activity selection
      transformed_content:
        if has_selection do
          transform_content(content, prototypes_with_revisions)
        else
          content
        end
    }
  end

  # Make a pass through the revision content model to gather all statically referenced activity ids
  # and to fulfill all activity bank selections.
  #
  # In order to prevent multiple selections on the page potentially realizing the same activity more
  # than once, we update the blacklisted activity ids within the source as we proceed through the
  # collection of activity references.
  defp fulfill(model, %Source{} = source, user, section_slug, existing_attempt_prototypes) do
    # Create a map of selection ids to a list of their existing prototypes
    prototypes_by_selection = build_prototypes_by_selection_map(existing_attempt_prototypes)

    # Create a map of activity id (aka resource id) to its existing prototype
    prototypes_by_activity_id =
      Enum.reduce(existing_attempt_prototypes, %{}, fn p, m ->
        Map.put(m, p.revision.resource_id, p)
      end)

    fulfillment_state = %{
      # These are the three items that we update throughout do_fulfill
      errors: [],
      prototypes: [],
      source: source,

      # These are here as context merely for optimizing access to existing prototypes
      prototypes_by_selection: prototypes_by_selection,
      prototypes_by_activity_id: prototypes_by_activity_id
    }

    Enum.reduce(model, fulfillment_state, fn e, state ->
      do_fulfill(state, e, nil, nil, user, section_slug)
    end)
  end

  defp do_fulfill(
         fulfillment_state,
         %{"type" => "activity-reference"} = model_component,
         group_id,
         survey_id,
         _user,
         _section_slug
       ) do
    # Create a new attempt prototype, or use an existing one if present for this activity id
    prototype =
      case Map.get(fulfillment_state.prototypes_by_activity_id, model_component["activity_id"]) do
        nil ->
          reference_to_prototype(model_component, group_id, survey_id)

        existing_prototype ->
          # update an existing one to make sure it tracks the latest survey and group context
          existing_prototype
          |> Map.put(:survey_id, survey_id)
          |> Map.put(:group_id, group_id)
      end

    fulfillment_state
    |> Map.put(:prototypes, [prototype | Map.get(fulfillment_state, :prototypes)])
  end

  # Just in time populate the meta data for activity bank questions
  defp do_fulfill(
         %{source: %{bank: nil, publication_id: publication_id}} = fulfillment_state,
         %{"type" => "selection"} = model_component,
         group_id,
         survey_id,
         user,
         section_slug
       ) do
    fulfillment_state = populate_bank(fulfillment_state, publication_id)

    do_fulfill(fulfillment_state, model_component, group_id, survey_id, user, section_slug)
  end

  defp do_fulfill(
         fulfillment_state,
         %{"type" => "selection"} = model_component,
         group_id,
         survey_id,
         _user,
         _section_slug
       ) do
    case Selection.parse(model_component) do
      {:error, "no values provided for expression"} ->
        fulfillment_state
        |> Map.put(:errors, [
          "Selection failed to fulfill: no values provided for expression"
          | fulfillment_state.errors
        ])

      {:ok, %Selection{points_per_activity: points_per_activity}} = result ->
        {:ok, %Selection{id: id} = selection} =
          decrement_for_prototypes(result, fulfillment_state.prototypes_by_selection)

        # Add any existing prototypes to the prototypes list for this selection and to the blacklist
        fulfillment_state = add_existing_for_selection(fulfillment_state, id)

        # Handle the case that existing prototypes for this selection completely decrement
        # the count down to zero
        if selection.count == 0 do
          fulfillment_state
        else
          # We need to draw some number of activities from the bank
          case Selection.fulfill(selection, fulfillment_state.source) do
            {:ok, %Result{} = result} ->
              new_prototypes =
                Enum.reverse(result.rows)
                |> Enum.map(fn r -> revision_to_prototype(r, group_id, survey_id, id) end)
                |> Enum.map(fn p -> Map.put(p, :out_of, points_per_activity / 1.0) end)

              fulfillment_state
              |> Map.put(:prototypes, new_prototypes ++ fulfillment_state.prototypes)
              |> Map.put(:source, merge_blacklist(fulfillment_state.source, result.rows))

            {:partial, %Result{} = result} ->
              missing = selection.count - result.rowCount

              error = "Selection failed to fulfill completely with #{missing} missing activities"

              new_prototypes =
                Enum.map(result.rows, fn r ->
                  revision_to_prototype(r, group_id, survey_id, id)
                end)
                |> Enum.map(fn p -> Map.put(p, :out_of, points_per_activity / 1.0) end)

              fulfillment_state
              |> Map.put(:prototypes, new_prototypes ++ fulfillment_state.prototypes)
              |> Map.put(:source, merge_blacklist(fulfillment_state.source, result.rows))
              |> Map.put(:errors, [error | fulfillment_state.errors])

            e ->
              error = "Selection failed to fulfill with error: #{e}"

              fulfillment_state
              |> Map.put(:errors, [error | fulfillment_state.errors])
          end
        end
    end
  end

  # fulfill any resource group types
  defp do_fulfill(
         fulfillment_state,
         %{"type" => type} = model_component,
         group_id,
         survey_id,
         user,
         section_slug
       ) do
    if PageContent.is_resource_group?(model_component) do
      case type do
        "group" ->
          Enum.reduce(model_component["children"], fulfillment_state, fn c, s ->
            do_fulfill(s, c, model_component["id"], survey_id, user, section_slug)
          end)

        "survey" ->
          Enum.reduce(model_component["children"], fulfillment_state, fn c, s ->
            do_fulfill(s, c, group_id, model_component["id"], user, section_slug)
          end)

        _ ->
          Enum.reduce(model_component["children"], fulfillment_state, fn c, s ->
            do_fulfill(s, c, group_id, survey_id, user, section_slug)
          end)
      end
    else
      fulfillment_state
    end
  end

  defp add_existing_for_selection(fulfillment_state, selection_id) do
    prototypes =
      fulfillment_state.prototypes_by_selection
      |> Map.get(selection_id, [])

    fulfillment_state
    |> Map.put(:prototypes, prototypes ++ fulfillment_state.prototypes)
    |> Map.put(
      :source,
      merge_blacklist(fulfillment_state.source, Enum.map(prototypes, fn p -> p.revision end))
    )
  end

  defp populate_bank(fulfillment_state, publication_id) do
    activity_type_id = ResourceType.id_for_activity()

    query =
      from r in Oli.Resources.Revision,
        join: pr in Oli.Publishing.PublishedResource,
        on: pr.revision_id == r.id,
        where: pr.publication_id == ^publication_id,
        where: r.deleted == false,
        where: r.resource_type_id == ^activity_type_id,
        where: r.scope == :banked,
        select: %{
          resource_id: pr.resource_id,
          tags: r.tags,
          objectives: r.objectives,
          activity_type_id: r.activity_type_id
        }

    bank =
      Repo.all(query)
      |> Enum.map(fn r -> BankEntry.from_map(r) end)
      |> Enum.shuffle()

    source = %Source{fulfillment_state.source | bank: bank}

    %{fulfillment_state | source: source}
  end

  defp reference_to_prototype(activity_reference, group_id, survey_id) do
    %AttemptPrototype{
      activity_id: activity_reference["activity_id"],
      survey_id: survey_id,
      group_id: group_id,
      selection_id: nil,
      inherit_state_from_previous: false
    }
  end

  defp revision_to_prototype(
         %BankEntry{resource_id: resource_id},
         group_id,
         survey_id,
         selection_id
       ) do
    %AttemptPrototype{
      activity_id: resource_id,
      survey_id: survey_id,
      group_id: group_id,
      selection_id: selection_id,
      inherit_state_from_previous: false
    }
  end

  defp revision_to_prototype(revision, group_id, survey_id, selection_id) do
    %AttemptPrototype{
      revision: revision,
      survey_id: survey_id,
      group_id: group_id,
      selection_id: selection_id,
      inherit_state_from_previous: false
    }
  end

  # For prototypes that do not have an out_of value set, set it from
  # sum of the max score for all parts from that activity
  defp set_out_of(%AttemptPrototype{out_of: nil, revision: revision} = p) do
    %{p | out_of: Oli.Grading.determine_activity_out_of(revision) / 1.0}
  end

  defp set_out_of(p), do: p

  # decrement the selection count by the size of any activity attempts prototypes
  # supplied for this selection. As a safeguard, be careful to never let a count go negative.
  defp decrement_for_prototypes(
         {:ok, %Selection{id: id, count: count} = selection},
         prototypes_by_selection
       ) do
    decrement = Map.get(prototypes_by_selection, id, []) |> Enum.count()

    new_count =
      if decrement > count do
        0
      else
        count - decrement
      end

    {:ok, %{selection | count: new_count}}
  end

  # At this point "prototypes" is a list of prototypes, some of which might need
  # to have a revision fetched.
  # Returns a list of prototypes.
  defp resolve_activity_ids(section_slug, prototypes, resolver) do
    activity_ids =
      Enum.filter(prototypes, fn p -> !is_nil(p.activity_id) end)
      |> Enum.map(fn p -> p.activity_id end)

    map =
      resolver.from_resource_id(section_slug, activity_ids)
      |> Enum.reduce(%{}, fn rev, m -> Map.put(m, rev.resource_id, rev) end)

    Enum.map(prototypes, fn p ->
      case p.revision do
        nil -> %{p | revision: Map.get(map, p.activity_id)}
        _ -> p
      end
    end)
  end

  defp build_prototypes_by_selection_map(prototypes) do
    Enum.reduce(prototypes, %{}, fn p, m ->
      case p.selection_id do
        nil -> m
        id -> Map.put(m, id, Map.get(m, id, []) ++ [p])
      end
    end)
  end

  # Replace all bank selections with activity-references that represent the fulfilled
  # activities for those selections
  defp transform_content(content, prototypes) do
    prototypes_by_selection = build_prototypes_by_selection_map(prototypes)

    mapped_model =
      transform_content_helper(content["model"], prototypes_by_selection) |> List.flatten()

    Map.put(content, "model", mapped_model)
  end

  defp transform_content_helper(model_component, prototypes_by_selection)
       when is_list(model_component) do
    Enum.map(model_component, fn component ->
      transform_content_helper(component, prototypes_by_selection)
    end)
  end

  defp transform_content_helper(
         %{"type" => "selection", "id" => id} = selection,
         prototypes_by_selection
       ) do
    Map.get(prototypes_by_selection, id)
    |> Enum.map(fn prototype -> replace_with_reference(selection, prototype.revision) end)
  end

  defp transform_content_helper(
         %{"children" => children} = component,
         prototypes_by_selection
       ) do
    if PageContent.is_resource_group?(component) do
      children = transform_content_helper(children, prototypes_by_selection) |> List.flatten()
      Map.put(component, "children", children)
    else
      component
    end
  end

  defp transform_content_helper(other, _) do
    other
  end

  # Takes a JSON selection element as a map and returns a list of activity-reference
  # JSON elements that represent which activities fulfilled the selection.
  defp replace_with_reference(selection_element, revision) do
    %{
      "type" => "activity-reference",
      "id" => Oli.Utils.uuid(),
      "activity_id" => revision.resource_id,
      "purpose" => Map.get(selection_element, "purpose", ""),
      "children" => [],
      "source-selection" => selection_element["id"]
    }
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
