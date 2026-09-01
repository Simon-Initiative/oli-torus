defmodule Oli.Delivery.Proficiency.ScopeMembership do
  @moduledoc """
  Derives page, container, and course objective membership from SectionResources.

  Membership is entirely delivery-pinned: page activity references are intersected
  with objective activity projections, then container membership is the union of
  descendant pages. Direct page-objective attachments are intentionally excluded.
  """

  alias Oli.Delivery.Sections.{Section, SectionResource, SectionResourceDepot}
  alias Oli.Resources.ResourceType

  @type scope :: {:page, pos_integer()} | {:container, pos_integer()} | :course

  @spec objectives_for_scopes(Section.t(), [scope()]) ::
          {:ok, %{optional(scope()) => MapSet.t(pos_integer())}} | {:error, term()}
  def objectives_for_scopes(%Section{} = section, scopes) do
    scopes = Enum.uniq(scopes)

    with :ok <- validate_scopes(scopes),
         {:ok, resources} <- SectionResourceDepot.proficiency_resources(section.id),
         :ok <- validate_scope_resources(section, resources, scopes) do
      {:ok, build_membership(section, resources, scopes)}
    else
      {:error, {:invalid_scope, _scope}} = error -> error
      {:error, reason} -> {:error, {:scope_membership_unavailable, reason}}
    end
  end

  @doc "Returns the descendant page resource IDs for each requested scope from the same depot snapshot."
  @spec pages_for_scopes(Section.t(), [scope()]) ::
          {:ok, %{optional(scope()) => MapSet.t(pos_integer())}} | {:error, term()}
  def pages_for_scopes(%Section{} = section, scopes) do
    scopes = Enum.uniq(scopes)

    with :ok <- validate_scopes(scopes),
         {:ok, resources} <- SectionResourceDepot.proficiency_resources(section.id),
         :ok <- validate_scope_resources(section, resources, scopes) do
      resources_by_id = Map.new(resources, &{&1.id, &1})
      resources_by_resource_id = Map.new(resources, &{&1.resource_id, &1})
      page_type = ResourceType.id_for_page()

      memberships =
        Map.new(scopes, fn scope ->
          root =
            case scope do
              :course -> Map.get(resources_by_id, section.root_section_resource_id)
              {_type, resource_id} -> Map.get(resources_by_resource_id, resource_id)
            end

          {scope, descendant_page_ids(root, resources_by_id, page_type)}
        end)

      {:ok, memberships}
    else
      {:error, {:invalid_scope, _scope}} = error -> error
      {:error, reason} -> {:error, {:scope_membership_unavailable, reason}}
    end
  end

  defp build_membership(section, resources, scopes) do
    objective_type = ResourceType.id_for_objective()
    page_type = ResourceType.id_for_page()

    activity_objectives =
      resources
      |> Enum.filter(&(&1.resource_type_id == objective_type))
      |> Enum.reduce(%{}, fn objective, index ->
        Enum.reduce(objective.related_activities, index, fn activity_id, index ->
          Map.update(
            index,
            activity_id,
            MapSet.new([objective.resource_id]),
            &MapSet.put(&1, objective.resource_id)
          )
        end)
      end)

    page_objectives =
      resources
      |> Enum.filter(&(&1.resource_type_id == page_type))
      |> Map.new(fn page ->
        # Repeated activities and objectives collapse here, so each LO contributes
        # at most once even when it occurs several times or on several pages.
        objectives =
          Enum.reduce(page.related_activities, MapSet.new(), fn activity_id, objectives ->
            MapSet.union(objectives, Map.get(activity_objectives, activity_id, MapSet.new()))
          end)

        {page.resource_id, objectives}
      end)

    resources_by_id = Map.new(resources, &{&1.id, &1})
    resources_by_resource_id = Map.new(resources, &{&1.resource_id, &1})

    scopes
    |> Enum.reduce({%{}, %{}}, fn scope, {membership, memo} ->
      {objectives, memo} =
        objectives_for_scope(
          scope,
          section,
          resources_by_id,
          resources_by_resource_id,
          page_objectives,
          memo
        )

      {Map.put(membership, scope, objectives), memo}
    end)
    |> elem(0)
  end

  defp objectives_for_scope(
         {:page, resource_id},
         _section,
         _resources,
         _resources_by_resource_id,
         page_objectives,
         memo
       ),
       do: {Map.get(page_objectives, resource_id, MapSet.new()), memo}

  defp objectives_for_scope(
         {:container, resource_id},
         _section,
         resources,
         resources_by_resource_id,
         page_objectives,
         memo
       ) do
    resources_by_resource_id
    |> Map.get(resource_id)
    |> descendant_page_objectives(resources, page_objectives, memo)
  end

  defp objectives_for_scope(
         :course,
         section,
         resources,
         _resources_by_resource_id,
         page_objectives,
         memo
       ) do
    resources
    |> Map.get(section.root_section_resource_id)
    |> descendant_page_objectives(resources, page_objectives, memo)
  end

  defp descendant_page_objectives(nil, _resources, _page_objectives, memo),
    do: {MapSet.new(), memo}

  defp descendant_page_objectives(
         %SectionResource{} = resource,
         resources,
         page_objectives,
         memo
       ) do
    case Map.fetch(memo, resource.id) do
      {:ok, objectives} ->
        {objectives, memo}

      :error ->
        objectives = Map.get(page_objectives, resource.resource_id)

        case objectives do
          %MapSet{} ->
            {objectives, Map.put(memo, resource.id, objectives)}

          nil ->
            {objectives, memo} =
              Enum.reduce(resource.children, {MapSet.new(), memo}, fn child_id,
                                                                      {objectives, memo} ->
                {child_objectives, memo} =
                  resources
                  |> Map.get(child_id)
                  |> descendant_page_objectives(resources, page_objectives, memo)

                {MapSet.union(objectives, child_objectives), memo}
              end)

            {objectives, Map.put(memo, resource.id, objectives)}
        end
    end
  end

  defp validate_scopes(scopes) do
    case Enum.find(scopes, &(not valid_scope?(&1))) do
      nil -> :ok
      scope -> {:error, {:invalid_scope, scope}}
    end
  end

  defp valid_scope?(:course), do: true

  defp valid_scope?({type, id}) when type in [:page, :container] and is_integer(id) and id > 0,
    do: true

  defp valid_scope?(_scope), do: false

  defp descendant_page_ids(nil, _resources, _page_type), do: MapSet.new()

  defp descendant_page_ids(resource, resources, page_type) do
    case resource.resource_type_id == page_type do
      true ->
        MapSet.new([resource.resource_id])

      false ->
        Enum.reduce(resource.children, MapSet.new(), fn child_id, page_ids ->
          MapSet.union(
            page_ids,
            descendant_page_ids(Map.get(resources, child_id), resources, page_type)
          )
        end)
    end
  end

  defp validate_scope_resources(section, resources, scopes) do
    page_type = ResourceType.id_for_page()
    container_type = ResourceType.id_for_container()

    page_ids =
      resources
      |> Enum.filter(&(&1.resource_type_id == page_type))
      |> MapSet.new(& &1.resource_id)

    container_ids =
      resources
      |> Enum.filter(&(&1.resource_type_id == container_type))
      |> MapSet.new(& &1.resource_id)

    valid_root? =
      Enum.any?(resources, fn resource ->
        resource.id == section.root_section_resource_id and
          resource.resource_type_id == container_type
      end)

    missing_scope =
      Enum.find(scopes, fn
        :course -> not valid_root?
        {:page, resource_id} -> not MapSet.member?(page_ids, resource_id)
        {:container, resource_id} -> not MapSet.member?(container_ids, resource_id)
      end)

    case missing_scope do
      nil -> :ok
      scope -> {:error, {:missing_scope_resource, scope}}
    end
  end
end
