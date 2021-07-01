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
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Publishing.Publication

  @doc """
  Enrolls a user in a course section
  ## Examples
      iex> enroll(user_id, section_id, [%ContextRole{}])
      {:ok, %Enrollment{}} # Inserted or updated with success

      iex> enroll(user_id, section_id, :open_and_free)
      {:error, changeset} # Something went wrong
  """
  @spec enroll(number(), number(), [%ContextRole{}]) :: {:ok, %Enrollment{}}
  def enroll(user_id, section_id, context_roles) do
    context_roles = EctoProvider.Marshaler.to(context_roles)

    case Repo.one(
           from(e in Enrollment,
             preload: [:context_roles],
             where: e.user_id == ^user_id and e.section_id == ^section_id,
             select: e
           )
         ) do
      # Enrollment doesn't exist, we are creating it
      nil -> %Enrollment{user_id: user_id, section_id: section_id}
      # Enrollment exists, we are potentially just updating it
      e -> e
    end
    |> Enrollment.changeset(%{section_id: section_id})
    |> Ecto.Changeset.put_assoc(:context_roles, context_roles)
    |> Repo.insert_or_update()
  end

  @doc """
  Determines if a particular user is enrolled in a section.

  """
  def is_enrolled?(user_id, section_slug) do
    query =
      from(
        e in Enrollment,
        join: s in Section,
        on: e.section_id == s.id,
        where: e.user_id == ^user_id and s.slug == ^section_slug and s.status != :deleted
      )

    case Repo.one(query) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Returns a listing of all enrollments for a given section.

  """
  def list_enrollments(section_slug) do
    query =
      from(
        e in Enrollment,
        join: s in Section,
        on: e.section_id == s.id,
        where: s.slug == ^section_slug and s.status != :deleted,
        preload: [:user, :context_roles],
        select: e
      )

    Repo.all(query)
  end

  def get_enrollment(section_slug, user_id) do
    query =
      from(
        e in Enrollment,
        join: s in Section,
        on: e.section_id == s.id,
        where: e.user_id == ^user_id and s.slug == ^section_slug and s.status != :deleted,
        select: e
      )

    Repo.one(query)
  end

  def update_enrollment(%Enrollment{} = e, attrs) do
    e
    |> Enrollment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a listing of all open and free sections for a given user.
  """
  def list_user_open_and_free_sections(%{id: user_id} = _user) do
    query =
      from(
        s in Section,
        join: e in Enrollment,
        on: e.section_id == s.id,
        where: e.user_id == ^user_id and s.open_and_free == true and s.status != :deleted,
        preload: [:project, :publication],
        select: s
      )

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
    Repo.all(
      from(
        s in Section,
        where: s.open_and_free == true and s.status != :deleted,
        select: s
      )
    )
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
  Gets a single section with preloaded associations.
  Raises `Ecto.NoResultsError` if the Section does not exist.
  ## Examples
      iex> get_section_preloaded!(123)
      %Section{}
      iex> get_section_preloaded!(456)
      ** (Ecto.NoResultsError)
  """
  def get_section_preloaded!(id) do
    from(s in Section,
      left_join: b in assoc(s, :brand),
      where: s.id == ^id,
      preload: [brand: b]
    )
    |> Repo.one!()
  end

  @doc """
  Gets a section's publication
  Raises `Ecto.NoResultsError` if the Section does not exist.
  ## Examples
      iex> get_section_publication!(123)
      %Publication{}
      iex> get_section_publication!(456)
      ** (Ecto.NoResultsError)
  """
  def get_section_publication!(id),
    do: (Repo.get!(Section, id) |> Repo.preload([:publication])).publication

  @doc """
  Gets a single section by query parameter
  ## Examples
      iex> get_section_by(slug: "123")
      %Section{}
      iex> get_section_by(slug: "111")
      nil
  """
  def get_section_by(clauses) do
    Repo.get_by(Section, clauses) |> Repo.preload([:publication, :project])
  end

  @doc """
  Gets a single section by slug and preloads associations
  ## Examples
      iex> get_section_by_slug"123")
      %Section{}
      iex> get_section_by_slug("111")
      nil
  """
  def get_section_by_slug(slug) do
    from(s in Section,
      left_join: pub in assoc(s, :publication),
      left_join: proj in assoc(s, :project),
      left_join: b in assoc(s, :brand),
      left_join: d in assoc(s, :lti_1p3_deployment),
      left_join: r in assoc(d, :registration),
      left_join: rb in assoc(r, :brand),
      where: s.slug == ^slug,
      preload: [
        publication: pub,
        project: proj,
        brand: b,
        lti_1p3_deployment: {d, registration: {r, brand: rb}}
      ]
    )
    |> Repo.one()
  end

  @doc """
  Gets a section using the given LTI params

  ## Examples
      iex> get_section_from_lti_params(lti_params)
      %Section{}
      iex> get_section_from_lti_params(lti_params)
      nil
  """
  def get_section_from_lti_params(lti_params) do
    context_id =
      Map.get(lti_params, "https://purl.imsglobal.org/spec/lti/claim/context")
      |> Map.get("id")

    issuer = lti_params["iss"]
    client_id = lti_params["aud"]

    Repo.one(
      from s in Section,
        join: d in Deployment,
        on: s.lti_1p3_deployment_id == d.id,
        join: r in Registration,
        on: d.registration_id == r.id,
        where:
          s.context_id == ^context_id and s.status != :deleted and r.issuer == ^issuer and
            r.client_id == ^client_id,
        select: s
    )
  end

  @doc """
  Gets the associated deployment and registration from the given section

  ## Examples
      iex> get_deployment_registration_from_section(section)
      {%Deployment{}, %Registration{}}
      iex> get_deployment_registration_from_section(section)
      nil
  """
  def get_deployment_registration_from_section(%Section{
        lti_1p3_deployment_id: lti_1p3_deployment_id
      }) do
    Repo.one(
      from d in Deployment,
        join: r in Registration,
        on: d.registration_id == r.id,
        where: ^lti_1p3_deployment_id == d.id,
        select: {d, r}
    )
  end

  @doc """
  Gets all sections that use a particular publication

  ## Examples
      iex> get_sections_by_publication("123")
      [%Section{}, ...]

      iex> get_sections_by_publication("456")
      ** (Ecto.NoResultsError)
  """
  # TODO: update query
  def get_sections_by_publication(publication) do
    from(s in Section, where: s.publication_id == ^publication.id and s.status != :deleted)
    |> Repo.all()
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
    from(s in Section, where: s.project_id == ^project.id and s.status != :deleted) |> Repo.all()
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
  Deletes a section by marking the record as deleted.
  ## Examples
      iex> soft_delete_section(section)
      {:ok, %Section{}}
      iex> soft_delete_section(section)
      {:error, %Ecto.Changeset{}}
  """
  def soft_delete_section(%Section{} = section) do
    update_section(section, %{status: :deleted})
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

  @doc """
  Create all section resources from the given section and publication using the
  root resource's revision tree. Returns the root section resource record.
  """
  def create_section_resources(
        %Section{} = section,
        %Publication{root_resource: root_resource} = publication
      ) do
    revisions_by_id =
      Oli.Publishing.get_published_revisions(publication)
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.resource_id, r) end)

    numberings = %{}
    level = 0

    {root_section_resource_id, _numberings} =
      create_section_resource(
        section,
        publication,
        revisions_by_id,
        Map.get(revisions_by_id, root_resource.id),
        level,
        numberings
      )

    update_section(section, %{root_section_resource_id: root_section_resource_id})
    |> case do
      {:ok, section} ->
        {:ok, Repo.preload(section, [:root_section_resource])}

      e ->
        e
    end
  end

  # This function constructs a section resource record by recursively calling itself on all the
  # children for the revision, then inserting the resulting struct into the database and returning its id.
  # This may not be the most efficient way of doing this but it seems to be the only way to create the records
  # in one go, otherwise section record creation then constructing relationships by updating the children
  # for each record would have to be two separate traversals
  defp create_section_resource(
         section,
         publication,
         revisions_by_id,
         revision,
         level,
         numberings
       ) do
    {numberings, numbering_index} = increment_count(numberings, level)

    {children, numberings} =
      Enum.reduce(
        revision.children,
        {[], numberings},
        fn resource_id, {children_ids, numberings} ->
          {id, numberings} =
            create_section_resource(
              section,
              publication,
              revisions_by_id,
              Map.get(revisions_by_id, resource_id),
              level + 1,
              numberings
            )

          {children_ids ++ [id], numberings}
        end
      )

    %SectionResource{id: section_resource_id} =
      Oli.Repo.insert!(%SectionResource{
        numbering_index: numbering_index,
        numbering_level: level,
        children: children,
        slug: revision.slug,
        resource_id: revision.resource_id,
        project_id: publication.project_id,
        section_id: section.id
      })

    {section_resource_id, numberings}
  end

  defp increment_count(numberings, level) do
    count = count_at_level(numberings, level) + 1

    {Map.put(numberings, level, count), count}
  end

  defp count_at_level(numberings, level) do
    case Map.get(numberings, level) do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Reconstructs the section resource hierarchy for a section
  """
  def get_section_resource_hierarchy(%Section{
        id: section_id,
        root_section_resource: root_section_resource
      }) do
    section_resources_by_id =
      all_section_resources(section_id)
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.id, r) end)

    section_resource_with_children(root_section_resource, section_resources_by_id)
  end

  defp all_section_resources(section_id) do
    from(sr in SectionResource,
      where: sr.section_id == ^section_id,
      select: sr
    )
    |> Repo.all()
  end

  defp section_resource_with_children(
         %SectionResource{children: children_ids} = section_resource,
         section_resources_by_id
       ) do
    Map.put(
      section_resource,
      :children,
      Enum.map(children_ids, fn c_id ->
        Map.get(section_resources_by_id, c_id)
        |> section_resource_with_children(section_resources_by_id)
      end)
    )
  end
end
