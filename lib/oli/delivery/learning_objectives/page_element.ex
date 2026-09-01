defmodule Oli.Delivery.LearningObjectives.PageElement do
  @moduledoc """
  Delivery-side discovery and render payload preparation for Learning Objectives page elements.

  The saved element state is advisory. This module resolves the authoritative objective set from
  the section's current published resources and uses the authored element only to decide whether
  the delivery render needs this payload and whether Summary proficiency should be included.
  """

  import Ecto.Query, warn: false

  alias Oli.Accounts.User
  alias Oli.Delivery.LearningObjectives.IncludedObjective
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Repo
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Revision

  @type render_payload :: %{
          container_resource_id: integer() | nil,
          objectives: [IncludedObjective.t()],
          objectives_by_id: %{integer() => IncludedObjective.t()},
          performance_by_objective_id: %{integer() => String.t()}
        }

  @page_type_id ResourceType.id_for_page()
  @container_type_id ResourceType.id_for_container()

  @spec prepare_render_payload(Section.t(), integer(), map(), User.t() | nil | struct()) ::
          render_payload() | nil
  @doc """
  Precomputes Learning Objectives data needed by delivery rendering for a page attempt.

  Returns `nil` without loading depot data when the page content has no top-level
  `learning_objectives` element. When present, discovery is scoped to the current page's
  delivery container, uses depot-backed schedule/objective data where possible, and adds
  Summary proficiency only for delivery student users.
  """
  def prepare_render_payload(section, current_page_resource_id, attempt_content, user) do
    prepare_render_payload(section, current_page_resource_id, attempt_content, user, [])
  end

  @doc false
  def prepare_render_payload(
        %Section{} = section,
        current_page_resource_id,
        attempt_content,
        user,
        opts
      ) do
    case learning_objectives_elements(attempt_content) do
      [] ->
        nil

      elements ->
        schedule = schedule(section.id, opts)

        container_resource_id =
          current_container_resource_id(section, current_page_resource_id, schedule)

        # objectives_with_children (only fetched when there are any in-scope
        # activities, see do_included_objectives/3) is reused by
        # maybe_proficiency/6 below for the same authoritative (not
        # page-scoped) hierarchy it needs to resolve a parent's Sub-LOs for
        # aggregation, instead of each independently re-fetching it.
        {:ok, objectives, objectives_with_children} =
          do_included_objectives(
            section,
            container_resource_id,
            Keyword.put(opts, :schedule, schedule)
          )

        objective_ids = Enum.map(objectives, & &1.resource_id)

        %{
          container_resource_id: container_resource_id,
          objectives: objectives,
          objectives_by_id: Map.new(objectives, &{&1.resource_id, &1}),
          performance_by_objective_id:
            maybe_proficiency(
              section,
              objective_ids,
              objectives_with_children,
              user,
              summary_element?(elements),
              opts
            )
        }
    end
  end

  @spec included_objectives(Section.t(), integer() | nil) ::
          {:ok, [IncludedObjective.t()]} | {:error, term()}
  @doc """
  Returns the delivery-authoritative objectives attached to activities in a container scope.

  The scan walks non-hidden descendant pages from `SectionResourceDepot`, reads page
  `activity_refs` in one narrow query, and filters depot-backed objectives by
  `related_activities`. Included ancestors are returned before their included children.
  """
  def included_objectives(section, container_resource_id) do
    included_objectives(section, container_resource_id, [])
  end

  @doc false
  def included_objectives(%Section{} = section, container_resource_id, opts) do
    {:ok, objectives, _objectives_with_children} =
      do_included_objectives(section, container_resource_id, opts)

    {:ok, objectives}
  end

  # Returns `{:ok, objectives, objectives_with_children}`, where
  # `objectives_with_children` is the section's authoritative objective
  # hierarchy fetched to build `objectives` (empty, and the depot left
  # unqueried, when there are no in-scope activities) — the caller can reuse
  # it (e.g. for proficiency aggregation) instead of re-fetching.
  defp do_included_objectives(%Section{} = section, container_resource_id, opts) do
    schedule = schedule(section.id, opts)
    container = container_section_resource(section, container_resource_id, schedule)

    pages = descendant_page_section_resources(container, schedule)
    activity_ids = in_scope_activity_ids(pages, opts)

    if MapSet.size(activity_ids) == 0 do
      {:ok, [], []}
    else
      objectives_with_children = objectives_with_effective_children(section.id, opts)
      objectives = included_objectives_for_activity_ids(objectives_with_children, activity_ids)
      {:ok, objectives, objectives_with_children}
    end
  end

  defp learning_objectives_elements(%{"model" => model}) when is_list(model) do
    Enum.filter(model, fn
      %{"type" => "learning_objectives"} -> true
      _ -> false
    end)
  end

  defp learning_objectives_elements(_), do: []

  defp summary_element?(elements) do
    Enum.any?(elements, fn
      %{"mode" => "summary"} -> true
      _ -> false
    end)
  end

  defp maybe_proficiency(_section, [], _objectives_with_children, _user, _summary?, _opts),
    do: %{}

  defp maybe_proficiency(
         _section,
         _objective_ids,
         _objectives_with_children,
         _user,
         false,
         _opts
       ),
       do: %{}

  defp maybe_proficiency(_section, _objective_ids, _objectives_with_children, nil, true, _opts),
    do: %{}

  defp maybe_proficiency(
         %Section{id: section_id},
         objective_ids,
         objectives_with_children,
         %User{id: user_id},
         true,
         opts
       ) do
    # A parent objective's proficiency must combine its Sub-LOs' evidence
    # (Metrics.evidence_resource_ids/2), which can include a Sub-LO that has no
    # activity in this page element's own scope (e.g. attempted elsewhere in
    # the course). `objectives_with_children` is the section's authoritative
    # objective hierarchy (not page-scoped), so this matches the same rule the
    # Instructor Dashboard uses (Sections.get_objectives_and_subobjectives/2)
    # for the same student.
    children_by_resource_id =
      Map.new(objectives_with_children, &{&1.resource_id, List.wrap(&1.children)})

    evidence_resource_ids_by_objective_id =
      Map.new(objective_ids, fn objective_id ->
        {objective_id,
         Metrics.evidence_resource_ids(
           objective_id,
           Map.get(children_by_resource_id, objective_id, [])
         )}
      end)

    all_evidence_resource_ids =
      evidence_resource_ids_by_objective_id
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()

    raw_proficiency_fun =
      Keyword.get(
        opts,
        :raw_proficiency_fun,
        &Metrics.raw_proficiency_per_student_for_objective/3
      )

    raw_proficiency_by_resource_id =
      raw_proficiency_fun.(section_id, all_evidence_resource_ids, student_id: user_id)

    Map.new(objective_ids, fn objective_id ->
      resource_ids = Map.fetch!(evidence_resource_ids_by_objective_id, objective_id)

      {objective_id,
       Metrics.proficiency_bucket_for_student(
         resource_ids,
         raw_proficiency_by_resource_id,
         user_id
       )}
    end)
  end

  defp maybe_proficiency(
         _section,
         _objective_ids,
         _objectives_with_children,
         _non_delivery_user,
         true,
         _opts
       ),
       do: %{}

  defp schedule(section_id, opts) do
    Keyword.get_lazy(opts, :schedule, fn ->
      schedule_fun = Keyword.get(opts, :schedule_fun, &SectionResourceDepot.retrieve_schedule/1)
      schedule_fun.(section_id)
    end)
  end

  defp objectives_with_effective_children(section_id, opts) do
    objectives_fun =
      Keyword.get(
        opts,
        :objectives_fun,
        &SectionResourceDepot.objectives_with_effective_children/1
      )

    objectives_fun.(section_id)
  end

  defp current_container_resource_id(%Section{} = section, current_page_resource_id, schedule) do
    by_resource_id = Map.new(schedule, &{&1.resource_id, &1})
    by_section_resource_id = Map.new(schedule, &{&1.id, &1})
    parent_by_child_section_resource_id = parent_by_child_section_resource_id(schedule)
    root = root_section_resource(section, schedule)

    with %SectionResource{id: page_section_resource_id} <-
           Map.get(by_resource_id, current_page_resource_id),
         parent_section_resource_id when not is_nil(parent_section_resource_id) <-
           Map.get(parent_by_child_section_resource_id, page_section_resource_id),
         %SectionResource{} = parent <-
           Map.get(by_section_resource_id, parent_section_resource_id) do
      parent.resource_id
    else
      _ -> root && root.resource_id
    end
  end

  defp container_section_resource(%Section{} = section, nil, schedule),
    do: root_section_resource(section, schedule)

  defp container_section_resource(%Section{} = section, container_resource_id, schedule) do
    schedule
    |> Enum.find(
      &(&1.resource_id == container_resource_id && &1.resource_type_id == @container_type_id)
    )
    |> case do
      nil -> root_section_resource(section, schedule)
      container -> container
    end
  end

  defp root_section_resource(
         %Section{root_section_resource_id: root_section_resource_id},
         schedule
       )
       when not is_nil(root_section_resource_id),
       do: Enum.find(schedule, &(&1.id == root_section_resource_id))

  defp root_section_resource(_section, schedule),
    do:
      Enum.find(schedule, &(&1.numbering_level == 0 && &1.resource_type_id == @container_type_id))

  defp parent_by_child_section_resource_id(schedule) do
    Enum.reduce(schedule, %{}, fn section_resource, acc ->
      section_resource.children
      |> List.wrap()
      |> Enum.reduce(acc, fn child_section_resource_id, acc ->
        Map.put(acc, child_section_resource_id, section_resource.id)
      end)
    end)
  end

  defp descendant_page_section_resources(nil, _schedule), do: []
  defp descendant_page_section_resources(%SectionResource{hidden: true}, _schedule), do: []

  defp descendant_page_section_resources(%SectionResource{} = container, schedule) do
    by_section_resource_id = Map.new(schedule, &{&1.id, &1})

    container.children
    |> List.wrap()
    |> Enum.flat_map(&descendant_pages(&1, by_section_resource_id))
  end

  defp descendant_pages(section_resource_id, by_section_resource_id) do
    case Map.get(by_section_resource_id, section_resource_id) do
      %SectionResource{hidden: true} ->
        []

      %SectionResource{resource_type_id: @page_type_id} = page ->
        [page]

      %SectionResource{resource_type_id: @container_type_id, children: children} ->
        # SectionResource children are section_resource IDs, not resource IDs. Keep this traversal
        # depot-backed so delivery does not recursively query the hierarchy while rendering pages.
        children
        |> List.wrap()
        |> Enum.flat_map(&descendant_pages(&1, by_section_resource_id))

      _ ->
        []
    end
  end

  defp in_scope_activity_ids([], _opts), do: MapSet.new()

  defp in_scope_activity_ids(page_section_resources, opts) do
    revision_ids =
      page_section_resources
      |> Enum.map(& &1.revision_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    activity_refs_fun =
      Keyword.get(opts, :activity_refs_fun, &activity_refs_by_page_revision_ids/1)

    # Page revisions maintain `activity_refs`, so one narrow query gets the activity boundary
    # for all descendant pages without walking page JSON during delivery render.
    revision_ids
    |> activity_refs_fun.()
    |> Enum.flat_map(&List.wrap/1)
    |> MapSet.new()
  end

  defp activity_refs_by_page_revision_ids([]), do: []

  defp activity_refs_by_page_revision_ids(revision_ids) do
    from(r in Revision,
      where: r.id in ^revision_ids,
      select: r.activity_refs
    )
    |> Repo.all()
  end

  defp included_objectives_for_activity_ids(objectives, activity_ids) do
    if MapSet.size(activity_ids) == 0 do
      []
    else
      objectives_by_resource_id = Map.new(objectives, &{&1.resource_id, &1})
      parent_ids_by_child_resource_id = parent_ids_by_child_resource_id(objectives)

      directly_matched_ids =
        objectives
        |> Enum.filter(fn objective ->
          objective.related_activities
          |> List.wrap()
          |> Enum.any?(&MapSet.member?(activity_ids, &1))
        end)
        |> Enum.map(& &1.resource_id)
        |> MapSet.new()

      included_ids =
        directly_matched_ids
        |> Enum.reduce(directly_matched_ids, fn objective_id, included_ids ->
          include_ancestors(objective_id, parent_ids_by_child_resource_id, included_ids)
        end)

      order_objectives(
        objectives_by_resource_id,
        parent_ids_by_child_resource_id,
        included_ids,
        directly_matched_ids,
        activity_ids
      )
    end
  end

  defp include_ancestors(objective_id, parent_ids_by_child_resource_id, included_ids) do
    parent_ids_by_child_resource_id
    |> Map.get(objective_id, [])
    |> Enum.reduce(included_ids, fn parent_id, included_ids ->
      include_ancestors(
        parent_id,
        parent_ids_by_child_resource_id,
        MapSet.put(included_ids, parent_id)
      )
    end)
  end

  defp parent_ids_by_child_resource_id(objectives) do
    objectives
    |> Enum.reduce(%{}, fn objective, acc ->
      objective.children
      |> List.wrap()
      |> Enum.reduce(acc, fn child_resource_id, acc ->
        Map.update(acc, child_resource_id, MapSet.new([objective.resource_id]), fn parent_ids ->
          MapSet.put(parent_ids, objective.resource_id)
        end)
      end)
    end)
    |> Enum.into(%{}, fn {child_resource_id, parent_ids} ->
      {child_resource_id, parent_ids |> MapSet.to_list() |> Enum.sort()}
    end)
  end

  defp order_objectives(
         objectives_by_resource_id,
         parent_ids_by_child_resource_id,
         included_ids,
         directly_matched_ids,
         activity_ids
       ) do
    children_by_parent_resource_id =
      objectives_by_resource_id
      |> Map.values()
      |> Enum.reduce(%{}, fn objective, acc ->
        objective.children
        |> List.wrap()
        |> Enum.filter(&MapSet.member?(included_ids, &1))
        |> Enum.reduce(acc, fn child_resource_id, acc ->
          child = Map.get(objectives_by_resource_id, child_resource_id)

          if is_nil(child) do
            acc
          else
            Map.update(acc, objective.resource_id, [child], &[child | &1])
          end
        end)
      end)
      |> Enum.into(%{}, fn {parent_id, children} -> {parent_id, sort_objectives(children)} end)

    roots =
      objectives_by_resource_id
      |> Map.values()
      |> Enum.filter(fn objective ->
        MapSet.member?(included_ids, objective.resource_id) &&
          not Enum.any?(
            Map.get(parent_ids_by_child_resource_id, objective.resource_id, []),
            &MapSet.member?(included_ids, &1)
          )
      end)
      |> sort_objectives()

    {ordered_objectives, emitted_ids} =
      visit_objectives(
        roots,
        children_by_parent_resource_id,
        parent_ids_by_child_resource_id,
        included_ids,
        [],
        MapSet.new()
      )

    remaining_objectives =
      included_ids
      |> MapSet.difference(emitted_ids)
      |> Enum.map(&Map.fetch!(objectives_by_resource_id, &1))
      |> sort_objectives()

    {ordered_objectives, _emitted_ids} =
      visit_objectives(
        remaining_objectives,
        children_by_parent_resource_id,
        parent_ids_by_child_resource_id,
        included_ids,
        ordered_objectives,
        emitted_ids
      )

    Enum.map(ordered_objectives, fn objective ->
      build_included_objective(
        objective,
        children_by_parent_resource_id,
        parent_ids_by_child_resource_id,
        directly_matched_ids,
        activity_ids
      )
    end)
  end

  defp visit_objectives(
         objectives,
         children_by_parent_resource_id,
         parent_ids_by_child_resource_id,
         included_ids,
         ordered_objectives,
         emitted_ids
       ) do
    Enum.reduce(objectives, {ordered_objectives, emitted_ids}, fn objective,
                                                                  {ordered_objectives,
                                                                   emitted_ids} ->
      visit_objective(
        objective,
        children_by_parent_resource_id,
        parent_ids_by_child_resource_id,
        included_ids,
        ordered_objectives,
        emitted_ids
      )
    end)
  end

  defp visit_objective(
         objective,
         children_by_parent_resource_id,
         parent_ids_by_child_resource_id,
         included_ids,
         ordered_objectives,
         emitted_ids
       ) do
    cond do
      MapSet.member?(emitted_ids, objective.resource_id) ->
        {ordered_objectives, emitted_ids}

      waiting_for_included_parent?(
        objective,
        parent_ids_by_child_resource_id,
        included_ids,
        emitted_ids
      ) ->
        {ordered_objectives, emitted_ids}

      true ->
        children = Map.get(children_by_parent_resource_id, objective.resource_id, [])

        visit_objectives(
          children,
          children_by_parent_resource_id,
          parent_ids_by_child_resource_id,
          included_ids,
          ordered_objectives ++ [objective],
          MapSet.put(emitted_ids, objective.resource_id)
        )
    end
  end

  defp waiting_for_included_parent?(
         objective,
         parent_ids_by_child_resource_id,
         included_ids,
         emitted_ids
       ) do
    parent_ids_by_child_resource_id
    |> Map.get(objective.resource_id, [])
    |> Enum.any?(fn parent_id ->
      MapSet.member?(included_ids, parent_id) && !MapSet.member?(emitted_ids, parent_id)
    end)
  end

  defp build_included_objective(
         objective,
         children_by_parent_resource_id,
         parent_ids_by_child_resource_id,
         directly_matched_ids,
         activity_ids
       ) do
    children = Map.get(children_by_parent_resource_id, objective.resource_id, [])
    parent_resource_ids = Map.get(parent_ids_by_child_resource_id, objective.resource_id, [])

    %IncludedObjective{
      resource_id: objective.resource_id,
      title: objective.title,
      parent_resource_id: List.first(parent_resource_ids),
      parent_resource_ids: parent_resource_ids,
      children: Enum.map(children, & &1.resource_id),
      related_activity_ids:
        objective.related_activities
        |> List.wrap()
        |> Enum.filter(&MapSet.member?(activity_ids, &1)),
      directly_matched?: MapSet.member?(directly_matched_ids, objective.resource_id)
    }
  end

  defp sort_objectives(objectives), do: Enum.sort_by(objectives, &{&1.title, &1.resource_id})
end
