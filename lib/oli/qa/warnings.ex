defmodule Oli.Qa.Warnings do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Qa.{Warning, Review}

  def dismiss_warning(warning_id) do
    get_warning!(warning_id)
    |> update_warning(%{
      is_dismissed: true
    })
  end

  def get_warning!(id), do: Repo.get!(Warning, id)

  def list_active_warnings(project_id) do
    Repo.all(
      from warning in Warning,
      join: review in assoc(warning, :review),
      where: review.project_id == ^project_id
        and warning.is_dismissed == false,
      select: warning,
      preload: [revision: :resource_type, review: review])
  end

  @doc """
  Creates a warning.
  ## Examples
      iex> create_warning(%{field: value})
      {:ok, %Warning{}}
      iex> create_warning(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_warning(attrs \\ %{}) do
    %Warning{}
    |> Warning.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a warning.
  ## Examples
      iex> update_warning(warning, %{field: new_value})
      {:ok, %Warning{}}
      iex> update_warning(warning, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_warning(%Warning{} = warning, attrs) do
    warning
    |> Warning.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking warning changes.
  ## Examples
      iex> change_warning(warning)
      %Ecto.Changeset{source: %Warning{}}
  """
  def change_warning(%Warning{} = warning) do
    Warning.changeset(warning, %{})
  end

  @doc """
  Deletes a warning.
  ## Examples
      iex> delete_warning(warning)
      {:ok, %Warning{}}
      iex> delete_warning(warning)
      {:error, %Ecto.Changeset{}}
  """
  def delete_warning(%Warning{} = warning) do
    Repo.delete(warning)
  end

  def delete_warnings(project_id) do
    Repo.delete_all(
      from warning in Warning,
      join: review in Review,
      on: warning.review_id == review.id,
      where: review.project_id == ^project_id)
  end
end
