defmodule Oli.Delivery.Sections do
  @moduledoc """
  The Sections context.
  """

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Delivery.Sections.SectionRole

  @doc """
  Enrolls a user in a course section.

  """
  def enroll(user_id, section_id, section_role_id) do

    case Repo.one(from(e in Enrollment, where: e.user_id == ^user_id and e.section_id == ^section_id, select: e)) do

      # Enrollment doesn't exist, we are creating it
      nil  -> %Enrollment{user_id: user_id, section_id: section_id, section_role_id: section_role_id}

      # Enrollment exists, we are potentially just updating it
      e -> e
    end
    |> Enrollment.changeset(%{ section_role_id: section_role_id})
    |> Repo.insert_or_update
  end

  @doc """
  Determines if a particular user is enrolled in a section with a given role.

  """
  def is_enrolled_as?(user_id, context_id, %SectionRole{id: id}) do
    query = from(
      e in Enrollment,
      join: s in Section, on: e.section_id == s.id,
      where: e.user_id == ^user_id and s.context_id == ^context_id and e.section_role_id == ^id)

    case Repo.one(query) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Determines if a particular user is enrolled in a section.

  """
  def is_enrolled?(user_id, context_id) do
    query = from(
      e in Enrollment,
      join: s in Section, on: e.section_id == s.id,
      where: e.user_id == ^user_id and s.context_id == ^context_id)

    case Repo.one(query) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Returns a listing of all enrollments for a given section context_id.

  """
  def list_enrollments(context_id) do
    query = from(
      e in Enrollment,
      join: s in Section, on: e.section_id == s.id,
      where: s.context_id == ^context_id,
      preload: [user: e],
      select: e)
    Repo.all(query)
  end

  @doc """
  Returns the list of sections.
  ## Examples
      iex> list_sections()
      [%Section{}, ...]
  """
  def list_sections do
    Repo.all(Section)
  end

  @doc """
  Gets a single section.
  Raises `Ecto.NoResultsError` if the Section does not exist.
  ## Examples
      iex> get_section!(123)
      %Section{}
      iex> get_section!(456)
      ** (Ecto.NoResultsError)
  """
  def get_section!(id), do: Repo.get!(Section, id)

  @doc """
  Gets a section's publication
  Raises `Ecto.NoResultsError` if the Section does not exist.
  ## Examples
      iex> get_section_publication!(123)
      %Publication{}
      iex> get_section_publication!(456)
      ** (Ecto.NoResultsError)
  """
  def get_section_publication!(id), do: (Repo.get!(Section, id) |> Repo.preload([:publication])).publication

  @doc """
  Gets a single section by query parameter
  ## Examples
      iex> get_section_by(context_id: "123")
      {:ok, %Section{}}
      iex> get_section_by(context_id: "111")
      { :error, changeset }
  """
  def get_section_by(clauses), do: Repo.get_by(Section, clauses) |> Repo.preload([:publication, :project])

  @doc """
  Gets all sections that use a particular publication

  ## Examples

      iex> get_sections_by_publication("123")
      [%Section{}, ...]

      iex> get_sections_by_publication("456")
      ** (Ecto.NoResultsError)

  """
  def get_sections_by_publication(publication) do
    from(s in Section, where: s.publication_id == ^publication.id) |> Repo.all()
  end

  @doc """
  Gets all sections that use a particular project

  ## Examples

      iex> get_sections_by_project(project)
      [%Section{}, ...]

      iex> get_sections_by_project(invalid_project)
      ** (Ecto.NoResultsError)

  """
  def get_sections_by_project(project) do
    from(s in Section, where: s.project_id == ^project.id) |> Repo.all()
  end

  @doc """
  Creates a section.
  ## Examples
      iex> create_section(%{field: value})
      {:ok, %Section{}}
      iex> create_section(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_section(attrs \\ %{}) do
    %Section{}
    |> Section.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a section.
  ## Examples
      iex> update_section(section, %{field: new_value})
      {:ok, %Section{}}
      iex> update_section(section, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_section(%Section{} = section, attrs) do
    section
    |> Section.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a section.
  ## Examples
      iex> delete_section(section)
      {:ok, %Section{}}
      iex> delete_section(section)
      {:error, %Ecto.Changeset{}}
  """
  def delete_section(%Section{} = section) do
    Repo.delete(section)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking section changes.
  ## Examples
      iex> change_section(section)
      %Ecto.Changeset{source: %Section{}}
  """
  def change_section(%Section{} = section) do
    Section.changeset(section, %{})
  end
end
