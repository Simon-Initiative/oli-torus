defmodule Oli.Delivery.Sections do
  @moduledoc """
  The Sections context.
  """
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Enrollment
  alias Lti_1p3.Tool.ContextRole
  alias Lti_1p3.DataProviders.EctoProvider
  alias Lti_1p3.DataProviders.EctoProvider.Deployment
  alias Oli.Lti_1p3.Tool.Registration

  @doc """
  Enrolls a user in a course section.

  """
  @spec enroll(number(), number(), [%ContextRole{}]) :: {:ok, %Enrollment{}}
  def enroll(user_id, section_id, context_roles) do
    context_roles = EctoProvider.Marshaler.to(context_roles)

    case Repo.one(from(e in Enrollment, preload: [:context_roles], where: e.user_id == ^user_id and e.section_id == ^section_id, select: e)) do

      # Enrollment doesn't exist, we are creating it
      nil  -> %Enrollment{user_id: user_id, section_id: section_id}

      # Enrollment exists, we are potentially just updating it
      e -> e
    end
    |> Enrollment.changeset(%{section_id: section_id})
    |> Ecto.Changeset.put_assoc(:context_roles, context_roles)
    |> Repo.insert_or_update
  end

  @doc """
  Determines if a particular user is enrolled in a section.

  """
  def is_enrolled?(user_id, section_slug) do
    query = from(
      e in Enrollment,
      join: s in Section, on: e.section_id == s.id,
      where: e.user_id == ^user_id and s.slug == ^section_slug)

    case Repo.one(query) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Returns a listing of all enrollments for a given section.

  """
  def list_enrollments(section_slug) do
    query = from(
      e in Enrollment,
      join: s in Section, on: e.section_id == s.id,
      where: s.slug == ^section_slug,
      preload: [:user, :context_roles],
      select: e)
    Repo.all(query)
  end

  @doc """
  Returns a listing of all open and free sections for a given user.
  """
  def list_user_open_and_free_sections(%{id: user_id} = _user) do
    query = from(
      s in Section,
      join: e in Enrollment, on: e.section_id == s.id,
      where: e.user_id == ^user_id and s.open_and_free == true,
      preload: [:project, :publication],
      select: s)
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
  Returns the list of open and free sections.
  ## Examples
      iex> list_open_and_free_sections()
      [%Section{}, ...]
  """
  def list_open_and_free_sections() do
    Repo.all from(
      s in Section,
      where: s.open_and_free == true,
      select: s)
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
      iex> get_section_by(slug: "123")
      %Section{}
      iex> get_section_by(slug: "111")
      nil
  """
  def get_section_by(clauses), do: Repo.get_by(Section, clauses) |> Repo.preload([:publication, :project])

  @doc """
  Gets a section using the given LTI params

  ## Examples
      iex> get_section_from_lti_params(lti_params)
      %Section{}
      iex> get_section_from_lti_params(lti_params)
      nil
  """
  def get_section_from_lti_params(lti_params) do
    context_id = Map.get(lti_params, "https://purl.imsglobal.org/spec/lti/claim/context")
      |> Map.get("id")
    issuer = lti_params["iss"]
    client_id = lti_params["aud"]

    Repo.one(from s in Section,
      join: d in Deployment, on: s.lti_1p3_deployment_id == d.id,
      join: r in Registration, on: d.registration_id == r.id,
      where: s.context_id == ^context_id and r.issuer == ^issuer and r.client_id == ^client_id,
      select: s)
  end

  @doc """
  Gets the associated deployment and registration from the given section

  ## Examples
      iex> get_deployment_registration_from_section(section)
      {%Deployment{}, %Registration{}}
      iex> get_deployment_registration_from_section(section)
      nil
  """
  def get_deployment_registration_from_section(%Section{lti_1p3_deployment_id: lti_1p3_deployment_id}) do
    Repo.one(from d in Deployment,
      join: r in Registration, on: d.registration_id == r.id,
      where: ^lti_1p3_deployment_id == d.id,
      select: {d, r})
  end

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
  def change_section(%Section{} = section, attrs \\ %{}) do
    Section.changeset(section, attrs)
  end
end
