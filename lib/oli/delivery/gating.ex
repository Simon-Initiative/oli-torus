defmodule Oli.Delivery.Gating do
  @moduledoc """
  The Delivery.Gating context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Gating.GatingCondition

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
end
