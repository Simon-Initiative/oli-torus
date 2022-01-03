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
  alias Oli.Delivery.Gating.ConditionTypes

  def browse_gating_conditions(
        %Section{id: section_id, slug: section_slug},
        %Paging{limit: limit, offset: offset},
        %Sorting{field: field, direction: direction},
        text_search \\ nil
      ) do
    filter_by_text =
      if text_search == "" or is_nil(text_search) do
        true
      else
        dynamic(
          [_gc, u, rev],
          ilike(rev.title, ^"%#{text_search}%") or
            ilike(u.name, ^"%#{text_search}%") or
            ilike(u.email, ^"%#{text_search}%") or
            ilike(u.given_name, ^"%#{text_search}%") or
            ilike(u.family_name, ^"%#{text_search}%")
        )
      end

    query =
      GatingCondition
      |> join(:left, [gc], u in User, on: u.id == gc.user_id)
      |> join(
        :inner,
        [gc, _],
        rev in subquery(
          from([pr: pr, rev: rev] in DeliveryResolver.section_resource_revisions(section_slug),
            select: rev
          )
        ),
        on: rev.resource_id == gc.resource_id
      )
      |> where(^filter_by_text)
      |> where([gc, _], gc.section_id == ^section_id)
      |> limit(^limit)
      |> offset(^offset)
      |> select_merge([gc, _, rev], %{
        total_count: fragment("count(*) OVER()"),
        revision: rev
      })

    query =
      case field do
        :title -> order_by(query, [_gc, _u, rev], {^direction, rev.title})
        :user -> order_by(query, [gc_, u, _rev], {^direction, u.name})
        :details -> query
        _ -> order_by(query, [gc, _u, _rev], {^direction, field(gc, ^field)})
      end

    Repo.all(query)
  end

  @doc """
  Returns the list of gating_conditions for a section

  ## Examples

      iex> list_gating_conditions(123, [1,2,3])
      [%GatingCondition{}, ...]

  """
  def list_gating_conditions(section_id) do
    from(gc in GatingCondition,
      where: gc.section_id == ^section_id
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of gating_conditions for a section and list of resource ids

  ## Examples

      iex> list_gating_conditions(123, [1,2,3])
      [%GatingCondition{}, ...]

  """
  def list_gating_conditions(section_id, resource_ids) do
    from(gc in GatingCondition,
      where:
        gc.section_id == ^section_id and
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
  Deletes a gating_condition.

  ## Examples

      iex> delete_gating_condition(gating_condition)
      {:ok, %GatingCondition{}}

      iex> delete_gating_condition(gating_condition)
      {:error, %Ecto.Changeset{}}

  """
  def delete_gating_condition(%GatingCondition{} = gating_condition) do
    Repo.delete(gating_condition)
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
  def resource_open(
        section,
        resource_id
      )
      when is_integer(resource_id),
      do: resource_open(section, Integer.to_string(resource_id))

  def resource_open(
        %Section{id: section_id, resource_gating_index: resource_gating_index},
        resource_id
      ) do
    if Map.has_key?(resource_gating_index, resource_id) do
      list_gating_conditions(section_id, Map.get(resource_gating_index, resource_id))
      |> Enum.all?(&condition_open/1)
    else
      true
    end
  end

  # Returns true if the gating condition passes
  defp condition_open(%GatingCondition{type: type} = gating_condition) do
    ConditionTypes.types()
    |> Enum.find(fn {_name, ct} -> ct.type() == type end)
    |> then(fn {_name, ct} -> ct.open?(gating_condition) end)
  end

  @doc """
  Returns a list of reasons why one or more gating conditions blocked access
  """
  def details(
        section,
        resource_id,
        format_datetime: format_datetime
      )
      when is_integer(resource_id),
      do: details(section, Integer.to_string(resource_id), format_datetime: format_datetime)

  def details(
        %Section{id: section_id, resource_gating_index: resource_gating_index},
        resource_id,
        format_datetime: format_datetime
      )
      when is_binary(resource_id) do
    if Map.has_key?(resource_gating_index, resource_id) do
      list_gating_conditions(section_id, Map.get(resource_gating_index, resource_id))
      |> Enum.reduce([], fn gc, acc ->
        [details(gc, format_datetime: format_datetime) | acc]
      end)
      |> Enum.filter(fn reason -> reason != nil end)
    else
      []
    end
  end

  # Returns true if the gating conditions passes
  defp details(%GatingCondition{type: type} = gating_condition, format_datetime: format_datetime) do
    ConditionTypes.types()
    |> Enum.find(fn {_name, ct} -> ct.type() == type end)
    |> then(fn {_name, ct} ->
      ct.details(gating_condition, format_datetime: format_datetime)
    end)
  end
end
