defmodule Oli.Qa.Reviews do
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Qa.Review

  def create_review(project, type) do
    create_review(%{
      project_id: project.id,
      type: type
    })
  end

  def mark_review_done(review) do
    review
    |> update_review(%{ done: true })
  end

  def get_review!(id), do: Repo.get!(Review, id)

  def list_reviews(project_id) do
    Repo.all(
      from warning in Review,
      where: warning.project_id == ^project_id)
  end

  @doc """
  Creates a review.
  ## Examples
      iex> create_review(%{field: value})
      {:ok, %Review{}}
      iex> create_review(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_review(attrs \\ %{}) do
    %Review{}
    |> Review.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a review.
  ## Examples
      iex> update_review(qa_review, %{field: new_value})
      {:ok, %Review{}}
      iex> update_review(qa_review, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_review(%Review{} = review, attrs) do
    review
    |> Review.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking review changes.
  ## Examples
      iex> change_review(review)
      %Ecto.Changeset{source: %Review{}}
  """
  def change_review(%Review{} = review) do
    Review.changeset(review, %{})
  end

  @doc """
  Deletes a review.
  ## Examples
      iex> delete_review(review)
      {:ok, %Review{}}
      iex> delete_review(review)
      {:error, %Ecto.Changeset{}}
  """
  def delete_review(%Review{} = review) do
    Repo.delete(review)
  end

  def delete_reviews(project_id) do
    Repo.delete_all(from review in Review,
      where: review.project_id == ^project_id)
  end
end
