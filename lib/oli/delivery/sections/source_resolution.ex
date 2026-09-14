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
    * `project:` / `publication:` - the project or publication must exist, and a
      publication must actually be published.
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
    authors are recognised through `admin?`. An actor with neither is the
    system-level path used by internal tooling, which is trusted.
    """

    @type t :: %__MODULE__{
            user: Oli.Accounts.User.t() | nil,
            author: Oli.Accounts.Author.t() | nil,
            admin?: boolean()
          }

    defstruct user: nil, author: nil, admin?: false

    @doc "Builds an actor, deriving admin status from the author's system role."
    @spec new(Oli.Accounts.User.t() | nil, Oli.Accounts.Author.t() | nil) :: t()
    def new(user \\ nil, author \\ nil) do
      author =
        case author || (user && Map.get(user, :author)) do
          %Ecto.Association.NotLoaded{} -> nil
          author -> author
        end

      %__MODULE__{user: user, author: author, admin?: Accounts.is_admin?(author)}
    end

    @doc "An actor with no identity, used by trusted internal callers."
    @spec system() :: t()
    def system, do: %__MODULE__{}

    @doc "True when this actor carries no identity at all."
    @spec system?(t()) :: boolean()
    def system?(%__MODULE__{user: nil, author: nil, admin?: false}), do: true
    def system?(%__MODULE__{}), do: false
  end

  @type source ::
          {:project, Project.t()}
          | {:publication, Publication.t()}
          | {:product, Section.t()}
          | {:previous_section, Section.t()}

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

  def resolve("publication:" <> id, %Actor{}, _section_spec) do
    with {:ok, id} <- parse_id(id),
         %Publication{} = publication <- Repo.get(Publication, id),
         false <- is_nil(publication.published) do
      {:ok, {:publication, Repo.preload(publication, :project)}}
    else
      _ -> {:error, :not_found}
    end
  end

  def resolve("project:" <> id, %Actor{}, _section_spec) do
    with {:ok, id} <- parse_id(id),
         %Project{status: :active} = project <- Repo.get(Project, id) do
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
  @spec copyable_sections(Actor.t(), term()) :: [Section.t()]
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

  defp product_visible?(_product, %Actor{admin?: true}, _section_spec), do: true

  defp product_visible?(product, %Actor{} = actor, section_spec) do
    case Actor.system?(actor) do
      true ->
        true

      false ->
        institution = SectionSpecification.get_institution(section_spec)

        user_can_see_product?(product, actor.user, institution) or
          author_can_see_product?(product, actor.author, institution)
    end
  end

  defp author_can_see_product?(_product, nil, _institution), do: false

  defp author_can_see_product?(product, %Author{} = author, %Institution{} = institution) do
    Blueprint.available_products(author, institution)
    |> Enum.any?(&(&1.id == product.id))
  end

  # Direct delivery carries no institution, so institution-scoped visibility does
  # not apply and the globally visible catalogue is the floor for an author.
  defp author_can_see_product?(product, %Author{}, nil) do
    Blueprint.available_products()
    |> Enum.any?(&(&1.id == product.id))
  end

  defp user_can_see_product?(_product, nil, _institution), do: false

  defp user_can_see_product?(product, %User{} = user, institution) do
    # `retrieve_visible_sources/2` reads `user.author`, and raises on an unloaded
    # association rather than treating it as absent.
    user
    |> Repo.preload(:author)
    |> Publishing.retrieve_visible_sources(institution)
    |> Enum.any?(fn
      %Section{id: id} -> id == product.id
      _ -> false
    end)
  end

  # A previous section is copyable by an administrator, or by a user who holds an
  # instructor role in that section. Enrollment alone is not enough: a student
  # enrolled in the section must not be able to copy it.
  defp section_copyable?(section, %Actor{} = actor, section_spec) do
    within_institution?(section, section_spec) and
      (actor.admin? or Actor.system?(actor) or
         Sections.is_instructor?(actor.user, section.slug))
  end

  # LTI creation is scoped to the launching institution. Direct delivery carries
  # no institution, and a source section with none is not institution-scoped.
  defp within_institution?(section, section_spec) do
    case {SectionSpecification.get_institution(section_spec), section.institution_id} do
      {nil, _} -> true
      {_institution, nil} -> true
      {institution, section_institution_id} -> institution.id == section_institution_id
    end
  end

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} -> {:ok, id}
      _ -> :error
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}
  defp parse_id(_), do: :error
end
