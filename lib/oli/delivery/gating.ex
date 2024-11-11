defmodule Oli.Delivery.Gating do
  @moduledoc """
  The Delivery.Gating context.
  """

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Hierarchy
  alias Oli.Accounts.User
  alias Oli.Delivery.Gating.ConditionTypes.ConditionContext
  alias Oli.Delivery.Gating.ConditionTypes

  def browse_gating_conditions(
        %Section{id: section_id, slug: section_slug},
        %Paging{limit: limit, offset: offset},
        %Sorting{field: field, direction: direction},
        parent_gate_id,
        text_search \\ nil
      ) do
    filter_by_text =
      if text_search == "" or is_nil(text_search) do
        true
      else
        dynamic(
          [_sr, _, _, _, rev, _gc, u],
          ilike(rev.title, ^"%#{text_search}%") or
            ilike(u.name, ^"%#{text_search}%") or
            ilike(u.email, ^"%#{text_search}%") or
            ilike(u.given_name, ^"%#{text_search}%") or
            ilike(u.family_name, ^"%#{text_search}%")
        )
      end

    filter_by_parent_gate_id =
      if is_nil(parent_gate_id) do
        dynamic(
          [_sr, _, _, _, _rev, gc, _u],
          is_nil(gc.parent_id)
        )
      else
        dynamic(
          [_sr, _, _, _, _rev, gc, _u],
          gc.parent_id == ^parent_gate_id
        )
      end

    query =
      from(
        [sr, _, _, _, rev] in DeliveryResolver.section_resource_revisions(section_slug),
        join: gc in GatingCondition,
        on: gc.resource_id == rev.resource_id,
        left_join: u in User,
        on: u.id == gc.user_id,
        where: ^filter_by_text,
        where: ^filter_by_parent_gate_id,
        where: gc.section_id == ^section_id,
        limit: ^limit,
        offset: ^offset,
        select: gc,
        select_merge: %{
          total_count: fragment("count(*) OVER()"),
          revision: rev,
          user: u
        }
      )

    query =
      case field do
        :title ->
          order_by(query, [_sr, _, _, _, rev, _gc, _u], {^direction, rev.title})

        :user ->
          order_by(query, [_sr, _, _, _, _rev, _gc, u], {^direction, u.name})

        :details ->
          query

        :numbering_index ->
          order_by(query, [sr, _, _, _, _rev, _gc, _u], {^direction, sr.numbering_index})

        _ ->
          order_by(query, [_sr, _, _, _, _rev, gc, _u], {^direction, field(gc, ^field)})
      end

    Repo.all(query)
  end

  def count_exceptions(gate_id) do
    Repo.one(from gc in GatingCondition, select: count("*"), where: gc.parent_id == ^gate_id)
  end

  @doc """
  Duplicates all top-level gates in a source section into a destination section.  Does
  not duplicate student specific exceptions.  Does not validate that resources in the gate
  exist within the destination section.
  """
  def duplicate_gates(%Section{} = source, %Section{} = destination) do
    Repo.transaction(fn _ ->
      list_gating_conditions(source.id)
      |> Enum.filter(fn gc -> is_nil(gc.parent_id) end)
      |> Enum.each(fn gc ->
        Map.take(gc, [:type, :graded_resource_policy, :resource_id])
        |> Map.merge(%{parent_id: nil, section_id: destination.id, data: Map.from_struct(gc.data)})
        |> create_gating_condition()
      end)
    end)
  end

  @doc """
  Returns the list of gating_conditions for a section, optionally restricted
  to only top-level conditions (i.e., not ones that are student exceptions)

  ## Examples

      iex> list_gating_conditions(123)
      [%GatingCondition{}, ...]

       iex> list_gating_conditions(123, true)
      [%GatingCondition{}, ...]

  """
  def list_gating_conditions(section_id, top_level_only \\ false) do
    filter_by_top_level =
      if is_nil(top_level_only) do
        dynamic(
          [gc],
          is_nil(gc.parent_id)
        )
      else
        true
      end

    query =
      GatingCondition
      |> where(^filter_by_top_level)
      |> where([gc], gc.section_id == ^section_id)

    Repo.all(query)
  end

  @doc """
  Returns the list of gating_conditions for a section, a user, and list of resource ids

  ## Examples

      iex> list_gating_conditions(123, 34, [1,2,3])
      [%GatingCondition{}, ...]

  """
  def list_gating_conditions(section_id, user_id, resource_ids) do
    from(gc in GatingCondition,
      where:
        gc.section_id == ^section_id and
          (is_nil(gc.user_id) or gc.user_id == ^user_id) and
          gc.resource_id in ^resource_ids
    )
    |> Repo.all()
  end

  @doc """
  Gets a single gating_condition.

  Raises `Ecto.NoResultsError` if the Gating condition does not exist.

  ## Examples

      iex> get_gating_condition!(123)
      %GatingCondition{}

      iex> get_gating_condition!(456)
      ** (Ecto.NoResultsError)

  """
  def get_gating_condition!(id), do: Repo.get!(GatingCondition, id)

  @doc """
  Creates a gating_condition.

  ## Examples

      iex> create_gating_condition(%{field: value})
      {:ok, %GatingCondition{}}

      iex> create_gating_condition(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_gating_condition(attrs \\ %{}) do
    %GatingCondition{}
    |> GatingCondition.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a gating_condition.

  ## Examples

      iex> update_gating_condition(gating_condition, %{field: new_value})
      {:ok, %GatingCondition{}}

      iex> update_gating_condition(gating_condition, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_gating_condition(%GatingCondition{} = gating_condition, attrs) do
    gating_condition
    |> GatingCondition.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a gating_condition, including any student-specific exceptions.

  ## Examples

      iex> delete_gating_condition(gating_condition)
      {:ok, %GatingCondition{}, 1}

      iex> delete_gating_condition(gating_condition_with_exceptions)
      {:ok, %GatingCondition{}, 5}

      iex> delete_gating_condition(gating_condition)
      {:error, %Ecto.Changeset{}}

  """
  def delete_gating_condition(%GatingCondition{id: id, parent_id: nil} = gating_condition) do
    case from(gc in GatingCondition, where: gc.id == ^id or gc.parent_id == ^id)
         |> Repo.delete_all() do
      {0, _} -> {:error, "Could not delete gating condition"}
      {count, _} -> {:ok, gating_condition, count}
    end
  end

  def delete_gating_condition(%GatingCondition{} = gating_condition) do
    case Repo.delete(gating_condition) do
      {:ok, gc} -> {:ok, gc, 1}
      e -> e
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking gating_condition changes.

  ## Examples

      iex> change_gating_condition(gating_condition)
      %Ecto.Changeset{data: %GatingCondition{}}

  """
  def change_gating_condition(%GatingCondition{} = gating_condition, attrs \\ %{}) do
    GatingCondition.changeset(gating_condition, attrs)
  end

  @doc """
  Updates a sections resource gating index
  """
  def update_resource_gating_index(%Section{} = section) do
    section
    |> Sections.update_section(%{
      resource_gating_index: generate_resource_gating_index(section)
    })
  end

  @doc """
  Returns a resource gating index for a particular section hierarchy

  A resource gating index is a map from resource_id to a list of resource_ids.
  The resource_ids in the list represent all hierarchy parent resources which
  have gating conditions associated with them
  """
  def generate_resource_gating_index(%Section{id: section_id, slug: section_slug}) do
    hierarchy = DeliveryResolver.full_hierarchy(section_slug)

    gated_resource_id_map =
      list_gating_conditions(section_id)
      |> Enum.reduce(%{}, fn rc, acc -> Map.put(acc, rc.resource_id, true) end)

    Hierarchy.gated_ancestry_map(hierarchy, gated_resource_id_map)
  end

  @doc """
  Returns true if all gating conditions pass for a resource and it's ancestors
  """
  def blocked_by(
        section,
        user,
        resource_id
      )
      when is_integer(resource_id),
      do: blocked_by(section, user, Integer.to_string(resource_id))

  def blocked_by(
        %Section{id: section_id, resource_gating_index: resource_gating_index} = section,
        %User{id: user_id} = user,
        resource_id
      ) do
    context = ConditionContext.init(user, section)

    if Map.has_key?(resource_gating_index, resource_id) do
      list_gating_conditions(section_id, user_id, Map.get(resource_gating_index, resource_id))
      |> blocks_access(context)
    else
      []
    end
  end

  # Returns true if the gating condition passes
  defp evaluate_condition(
         %GatingCondition{type: type} = gating_condition,
         %ConditionContext{} = context
       ) do
    ConditionTypes.types()
    |> Enum.find(fn {_name, ct} -> ct.type() == type end)
    |> then(fn {_name, ct} -> ct.evaluate(gating_condition, context) end)
  end

  @doc """
  From a collection of gating conditions, return the conditions that block access to
  the resource.  This takes into account user-specific overrides.
  """
  def blocks_access(gating_conditions, %ConditionContext{} = context) do
    # Get the set of user-specific conditions, if any.  Map them by their parent_id
    # (which is the id of the parent user-wide condition)
    user_specific_map =
      Enum.reduce(gating_conditions, %{}, fn gc, m ->
        if is_nil(gc.parent_id) do
          m
        else
          Map.put(m, gc.parent_id, gc)
        end
      end)

    Enum.reduce(gating_conditions, {context, []}, fn gc, {context, blocks} ->
      # Consider only the user-wide conditions
      if is_nil(gc.user_id) do
        # But allow a user-specific condition to override
        condition =
          case Map.get(user_specific_map, gc.id) do
            nil -> gc
            user_specific -> user_specific
          end

        case evaluate_condition(condition, context) do
          {true, context} -> {context, blocks}
          {false, context} -> {context, [condition | blocks]}
        end
      else
        {context, blocks}
      end
    end)
    |> then(fn {_, blocks} -> blocks end)
  end

  @doc """
  Returns a list of reasons why one or more gating conditions blocked access
  """
  def details(
        blocking_gates,
        format_datetime: format_datetime
      )
      when is_list(blocking_gates) do
    Enum.map(blocking_gates, fn gc -> details(gc, format_datetime: format_datetime) end)
  end

  def details(%GatingCondition{type: type} = gating_condition, format_datetime: format_datetime) do
    ConditionTypes.types()
    |> Enum.find(fn {_name, ct} -> ct.type() == type end)
    |> then(fn {_name, ct} ->
      ct.details(gating_condition, format_datetime: format_datetime)
    end)
  end
end
