defmodule Oli.Delivery.Sections.SourceResolution do
  @moduledoc """
  Resolves and authorizes the source identifier a new section is created from.

  Section creation identifies its source with an opaque string submitted by the
  client (`"project:12"`, `"publication:34"`, `"product:56"`, `"section:78"`).
  Filtering the source-selection UI is not authorization: the identifier arrives
  verbatim from the browser, so eligibility has to be enforced here, in the
  domain layer, on every creation.

  ## Error contract

  Every failure - malformed identifier, missing record, wrong record type,
  ineligible source, or an actor with no right to it - returns
  `{:error, :not_found}`. Distinguishing "does not exist" from "not yours" would
  turn this into an existence oracle for section and product ids.

  ## Eligibility

    * `product:` - an active section of type `:blueprint` the actor can see.
    * `section:` - an active section of type `:enrollable` in which the actor
      holds an instructor role, or any such section for an administrator.
      Institution boundaries are enforced for LTI creation.
    * `project:` / `publication:` - the project or publication must exist and be
      visible to the actor under the applicable institution policy. A publication
      must also actually be published.
  """

  import Ecto.Query, warn: false

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Accounts.User
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionSpecification
  alias Oli.Institutions.Institution
  alias Oli.Publishing
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo

  defmodule Actor do
    @moduledoc """
    Who is creating a section.

    Both a delivery `user` and an authoring `author` may be present; admin
    authors are recognised through `admin?`. Missing identities are denied by
    default. Trusted internal tooling must opt into `system/0` explicitly.
    """

    @type t :: %__MODULE__{
            user: %Oli.Accounts.User{} | nil,
            author: %Oli.Accounts.Author{} | nil,
            admin?: boolean(),
            system?: boolean()
          }

    defstruct user: nil, author: nil, admin?: false, system?: false

    @doc "Builds an actor, deriving admin status from the author's system role."
    @spec new(%Oli.Accounts.User{} | nil, %Oli.Accounts.Author{} | nil) :: t()
    def new(user \\ nil, author \\ nil) do
      author =
        case author || (user && Map.get(user, :author)) do
          %Ecto.Association.NotLoaded{} -> nil
          author -> author
        end

      %__MODULE__{user: user, author: author, admin?: Accounts.is_admin?(author)}
    end

    @doc "Builds an explicitly trusted actor for internal, non-request callers."
    @spec system() :: t()
    def system, do: %__MODULE__{system?: true}

    @doc "True only for an actor explicitly constructed by `system/0`."
    @spec system?(t()) :: boolean()
    def system?(%__MODULE__{system?: true}), do: true
    def system?(%__MODULE__{}), do: false
  end

  @type source ::
          {:project, %Project{}}
          | {:publication, %Publication{}}
          | {:product, %Section{}}
          | {:previous_section, %Section{}}

  @doc """
  Resolves `identifier` into a typed, authorized source.

  Returns `{:ok, {kind, struct}}` or `{:error, :not_found}`.

  ## Examples

      iex> Oli.Delivery.Sections.SourceResolution.resolve("nonsense", actor, spec)
      {:error, :not_found}
  """
  @spec resolve(String.t(), Actor.t(), term()) :: {:ok, source()} | {:error, :not_found}
  def resolve(identifier, actor, section_spec)

  def resolve("product:" <> id, %Actor{} = actor, section_spec) do
    with {:ok, id} <- parse_id(id),
         %Section{type: :blueprint, status: :active} = product <- Repo.get(Section, id),
         true <- product_visible?(product, actor, section_spec) do
      {:ok, {:product, product}}
    else
      _ -> {:error, :not_found}
    end
  end

  def resolve("section:" <> id, %Actor{} = actor, section_spec) do
    with {:ok, id} <- parse_id(id),
         %Section{type: :enrollable, status: :active} = section <- Repo.get(Section, id),
         true <- section_copyable?(section, actor, section_spec) do
      {:ok, {:previous_section, section}}
    else
      _ -> {:error, :not_found}
    end
  end

  def resolve("publication:" <> id, %Actor{} = actor, section_spec) do
    with {:ok, id} <- parse_id(id),
         %Publication{} = publication <- Repo.get(Publication, id),
         false <- is_nil(publication.published),
         publication <- Repo.preload(publication, :project),
         true <- source_visible?(publication, actor, section_spec) do
      {:ok, {:publication, publication}}
    else
      _ -> {:error, :not_found}
    end
  end

  def resolve("project:" <> id, %Actor{} = actor, section_spec) do
    with {:ok, id} <- parse_id(id),
         %Project{status: :active} = project <- Repo.get(Project, id),
         true <- source_visible?(project, actor, section_spec) do
      {:ok, {:project, project}}
    else
      _ -> {:error, :not_found}
    end
  end

  def resolve(_identifier, %Actor{}, _section_spec), do: {:error, :not_found}

  @doc """
  Lists the sections an actor may copy as a previous course section.

  Instructors see active enrollable sections in which they hold an instructor
  role. Administrators see every active enrollable section, scoped to the
  institution when creating through LTI. This is the query the source-selection
  UI should use; `resolve/3` re-checks the same rules on submission.
  """
  @spec copyable_sections(Actor.t(), term()) :: [%Section{}]
  def copyable_sections(%Actor{admin?: true}, section_spec) do
    base_copyable_query()
    |> scope_to_institution(SectionSpecification.get_institution(section_spec))
    |> Repo.all()
  end

  def copyable_sections(%Actor{user: %User{id: user_id}}, section_spec) do
    instructor_role_ids = Sections.get_instructor_role_ids()

    base_copyable_query()
    |> join(:inner, [s], e in Sections.Enrollment, on: e.section_id == s.id)
    |> where([_s, e], e.user_id == ^user_id and e.status == :enrolled)
    |> join(:inner, [_s, e], ecr in "enrollments_context_roles", on: ecr.enrollment_id == e.id)
    |> where([_s, _e, ecr], ecr.context_role_id in ^instructor_role_ids)
    |> distinct(true)
    |> scope_to_institution(SectionSpecification.get_institution(section_spec))
    |> Repo.all()
  end

  def copyable_sections(%Actor{}, _section_spec), do: []

  defp base_copyable_query do
    from(s in Section,
      where: s.type == :enrollable and s.status == :active,
      order_by: [asc: s.title]
    )
  end

  defp scope_to_institution(query, nil), do: query

  defp scope_to_institution(query, institution),
    do: where(query, [s], s.institution_id == ^institution.id)

  # ---------------------------------------------------------------------------
  # Authorization
  # ---------------------------------------------------------------------------

  defp product_visible?(product, %Actor{} = actor, section_spec) do
    source_visible?(product, actor, section_spec)
  end

  # Direct-delivery administrators historically have access to every active
  # source. LTI creation still goes through the institution-aware catalogue so
  # an admin account cannot accidentally cross the launch tenant boundary.
  defp source_visible?(_source, %Actor{admin?: true}, section_spec)
       when not is_struct(section_spec, SectionSpecification.Lti),
       do: true

  defp source_visible?(_source, %Actor{} = actor, _section_spec)
       when actor.system?,
       do: true

  defp source_visible?(source, %Actor{} = actor, section_spec) do
    actor
    |> visible_sources(SectionSpecification.get_institution(section_spec))
    |> Enum.any?(&same_source?(&1, source))
  end

  defp visible_sources(%Actor{user: %User{} = user}, institution) do
    user
    |> Repo.preload(:author)
    |> Publishing.retrieve_visible_sources(institution)
  end

  defp visible_sources(%Actor{author: %Author{} = author}, institution) do
    Publishing.available_publications(author, institution) ++
      visible_products(author, institution)
  end

  defp visible_sources(%Actor{}, _institution), do: []

  defp visible_products(author, %Institution{} = institution),
    do: Blueprint.available_products(author, institution)

  defp visible_products(_author, nil), do: Blueprint.available_products()

  defp same_source?(%Publication{id: id}, %Publication{id: id}), do: true
  defp same_source?(%Publication{project_id: project_id}, %Project{id: project_id}), do: true

  defp same_source?(%Section{id: id, type: :blueprint}, %Section{id: id, type: :blueprint}),
    do: true

  defp same_source?(_visible, _source), do: false

  # A previous section is copyable by an administrator, or by a user who holds an
  # instructor role in that section. Enrollment alone is not enough: a student
  # enrolled in the section must not be able to copy it.
  defp section_copyable?(section, %Actor{} = actor, section_spec) do
    within_institution?(section, section_spec) and
      (actor.admin? or Actor.system?(actor) or
         Sections.is_instructor?(actor.user, section.slug))
  end

  # LTI creation is scoped strictly to the launching institution. Direct
  # delivery carries no institution boundary.
  defp within_institution?(section, section_spec) do
    case {SectionSpecification.get_institution(section_spec), section.institution_id} do
      {nil, _} -> true
      {institution, section_institution_id} -> institution.id == section_institution_id
    end
  end

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} -> {:ok, id}
      _ -> :error
    end
  end

  defp parse_id(_), do: :error
end
