defmodule Oli.Delivery.SectionCreation do
  @moduledoc """
  Authorization boundary for course section creation.

  Two questions, one rule each: may this actor create a section, and may it create one
  from this source. The course builder's source list renders from the same queries the
  gate resolves against, so the list never offers what the gate refuses.
  """

  import Ecto.Query, warn: false

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}
  alias Oli.Authoring.Course.ProjectVisibility
  alias Oli.Delivery.SectionCreationRequest
  alias Oli.Delivery.Sections.{Enrollment, Section, SectionSpecification}
  alias Oli.Groups
  alias Oli.Groups.CommunityVisibility
  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Lti.LaunchIdentity
  alias Oli.Lti.LtiParams
  alias Oli.Lti.Tool.{Deployment, Registration}
  alias Oli.Publishing
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo

  @instructor_context_role_ids [
    ContextRoles.get_role(:context_instructor).id,
    ContextRoles.get_role(:context_content_developer).id
  ]

  @doc """
  Reloads the tagged actor of a request. A missing or deleted account is refused.
  """
  @spec load_actor(Oli.Delivery.SectionCreationRequest.actor()) ::
          {:ok, User.t() | Author.t()} | {:error, :unauthorized}
  def load_actor({:user, id}) when is_integer(id) do
    case Accounts.get_user(id, preload: [:author]) do
      %User{} = user -> {:ok, user}
      _ -> {:error, :unauthorized}
    end
  end

  def load_actor({:author, id}) when is_integer(id) do
    case Accounts.get_author(id) do
      %Author{} = author -> {:ok, author}
      _ -> {:error, :unauthorized}
    end
  end

  def load_actor(_actor), do: {:error, :unauthorized}

  @doc """
  Decides whether the actor may create a section under the given specification, and
  returns the specification the creation must use.

  An author actor must be an administrator. A direct delivery user must hold
  `can_create_sections`. An LTI user must have a persisted launch bound to this user,
  issuer, client, deployment and context, carrying a role that may configure a section;
  the direct delivery right never substitutes for it.

  For an LTI user the returned specification is rebuilt from the persisted launch that was
  authorized — its claims, institution, registration and deployment — so the destination
  can never be a launch the actor did not prove.
  """
  @spec authorize_actor(User.t() | Author.t(), struct()) ::
          {:ok, struct()} | {:error, :unauthorized}
  def authorize_actor(actor, section_spec)

  def authorize_actor(%Author{} = author, section_spec) do
    if Accounts.is_admin?(author), do: complete_spec(section_spec), else: {:error, :unauthorized}
  end

  def authorize_actor(%User{} = user, %SectionSpecification.Direct{} = section_spec) do
    if user.can_create_sections, do: {:ok, section_spec}, else: {:error, :unauthorized}
  end

  def authorize_actor(%User{} = user, %SectionSpecification.Lti{lti_params: lti_params}) do
    with {:ok, identity} <- LaunchIdentity.from_claims(lti_params),
         %LtiParams{} = launch <- LtiParams.get_lti_params_for_user_launch(user.id, identity),
         true <- LtiParams.can_configure_section_from_params?(launch.params) do
      canonical_spec(identity, launch.params)
    else
      _ -> {:error, :unauthorized}
    end
  end

  def authorize_actor(_actor, _section_spec), do: {:error, :unauthorized}

  # An administrator has no launch of their own, so the specification is rebuilt from its
  # own claims: the destination always comes from one resolved launch identity.
  defp complete_spec(%SectionSpecification.Direct{} = section_spec), do: {:ok, section_spec}

  defp complete_spec(%SectionSpecification.Lti{lti_params: lti_params}) do
    case LaunchIdentity.from_claims(lti_params) do
      {:ok, identity} -> canonical_spec(identity, lti_params)
      :error -> {:error, :unauthorized}
    end
  end

  defp complete_spec(_section_spec), do: {:error, :unauthorized}

  defp canonical_spec(%LaunchIdentity{} = identity, params) do
    case Institutions.get_institution_registration_deployment(
           identity.issuer,
           identity.client_id,
           identity.deployment_id
         ) do
      {%Institution{} = institution, %Registration{} = registration, %Deployment{} = deployment} ->
        {:ok,
         %SectionSpecification.Lti{
           lti_params: params,
           institution: institution,
           registration: registration,
           deployment: deployment,
           identity: identity
         }}

      _ ->
        {:error, :unauthorized}
    end
  end

  @doc """
  Resolves a parsed source by membership in its kind's permitted query. Forbidden,
  nonexistent and retired sources get the same refusal.
  """
  @spec resolve_source(
          User.t() | Author.t(),
          Oli.Delivery.SectionCreationRequest.source(),
          Institution.t() | nil
        ) :: {:ok, {atom(), struct()}} | {:error, :unauthorized}
  def resolve_source(actor, source, institution)

  def resolve_source(actor, {:publication, id}, institution) do
    if SectionCreationRequest.valid_id?(id),
      do: resolve_publication(actor, id, institution),
      else: {:error, :unauthorized}
  end

  def resolve_source(actor, {:product, id}, institution) do
    if SectionCreationRequest.valid_id?(id),
      do: resolve_product(actor, id, institution),
      else: {:error, :unauthorized}
  end

  def resolve_source(actor, {:section, id}, institution) do
    if SectionCreationRequest.valid_id?(id),
      do: resolve_section(actor, id, institution),
      else: {:error, :unauthorized}
  end

  def resolve_source(_actor, _source, _institution), do: {:error, :unauthorized}

  defp resolve_publication(actor, id, institution) do
    actor
    |> permitted_publications_query(institution)
    |> where([publication: publication], publication.id == ^id)
    |> Repo.one()
    |> found(:publication)
  end

  defp resolve_product(actor, id, institution) do
    actor
    |> permitted_products_query(institution)
    |> where([product: product], product.id == ^id)
    |> Repo.one()
    |> found(:product)
  end

  defp resolve_section(actor, id, institution) do
    actor
    |> permitted_sections_query(institution)
    |> where([section: section], section.id == ^id)
    |> Repo.one()
    |> found(:section)
  end

  @doc """
  Published publications the actor may create a section from: an active project the actor
  can see, with no active paid product anywhere for that project.
  """
  def permitted_publications_query(actor, institution) do
    from(publication in Publication,
      as: :publication,
      join: project in assoc(publication, :project),
      as: :project,
      where: not is_nil(publication.published) and project.status == :active,
      where: not exists(active_paid_product_query()),
      preload: [project: project]
    )
    |> where(^project_scoped_visibility(actor, institution))
  end

  @doc """
  Products the actor may create a section from: active blueprints visible to the actor.
  """
  def permitted_products_query(actor, institution) do
    from(product in Section,
      as: :product,
      join: project in assoc(product, :base_project),
      as: :project,
      where: product.type == :blueprint and product.status == :active,
      preload: [base_project: project]
    )
    |> where(^product_visibility(actor, institution))
  end

  @doc """
  Sections the actor may create a section from: active enrollable sections the actor
  teaches, or any of them for an administrator, whose source project or blueprint is
  currently available to the actor in the course builder. Blueprint-based sections
  require access to that exact blueprint; project access alone does not substitute.
  LTI sources are restricted to the launching institution; direct-delivery sources
  have no institution boundary.
  """
  @spec permitted_sections_query(%User{} | %Author{}, %Institution{} | nil) :: Ecto.Query.t()
  def permitted_sections_query(actor, institution \\ nil) do
    permitted_project_ids =
      actor
      |> permitted_publications_query(institution)
      |> exclude(:preload)
      |> select([publication: publication], publication.project_id)

    permitted_product_ids =
      actor
      |> permitted_products_query(institution)
      |> exclude(:preload)
      |> select([product: product], product.id)

    from(section in Section,
      as: :section,
      where: section.type == :enrollable and section.status == :active,
      where:
        (is_nil(section.blueprint_id) and
           section.base_project_id in subquery(permitted_project_ids)) or
          section.blueprint_id in subquery(permitted_product_ids)
    )
    |> where(^section_entitlement(actor))
    |> scope_sections_to_institution(institution)
  end

  @doc """
  Lists the source publications of `permitted_publications_query/2`: the latest published
  publication of each permitted project, as the course builder offers them. The gate still
  resolves any published publication of a permitted project, so a chosen publication stays
  usable after a newer one is published.
  """
  def permitted_publications(actor, institution) do
    actor
    |> permitted_publications_query(institution)
    |> join(
      :inner,
      [publication: publication],
      latest in subquery(Publishing.last_publication_query()),
      on: latest.id == publication.id
    )
    |> Repo.all()
  end

  @doc """
  Lists the products of `permitted_products_query/2`.
  """
  def permitted_products(actor, institution),
    do: actor |> permitted_products_query(institution) |> Repo.all()

  @doc """
  Lists the sections of `permitted_sections_query/2`, optionally institution-scoped.
  """
  def permitted_sections(actor, institution \\ nil),
    do: actor |> permitted_sections_query(institution) |> Repo.all()

  defp scope_sections_to_institution(query, nil), do: query

  defp scope_sections_to_institution(query, %Institution{id: institution_id}),
    do: where(query, [section: section], section.institution_id == ^institution_id)

  defp found(%Publication{} = publication, :publication), do: {:ok, {:publication, publication}}
  defp found(%Section{} = section, kind), do: {:ok, {kind, section}}
  defp found(_result, _kind), do: {:error, :unauthorized}

  defp active_paid_product_query do
    from(product in Section,
      where:
        product.base_project_id == parent_as(:project).id and product.type == :blueprint and
          product.status == :active and product.requires_payment == true,
      select: 1
    )
  end

  defp project_scoped_visibility(%Author{} = author, _institution) do
    if Accounts.is_admin?(author), do: dynamic(true), else: dynamic(false)
  end

  defp project_scoped_visibility(%User{} = user, institution) do
    {communities, global_access?} = community_scope(user, institution)

    dynamic(false)
    |> or_global(global_access?)
    |> or_author(author_of(user))
    |> or_institution(institution)
    |> or_community_project(communities)
  end

  defp project_scoped_visibility(_actor, _institution), do: dynamic(false)

  defp product_visibility(%Author{} = author, institution),
    do: project_scoped_visibility(author, institution)

  defp product_visibility(%User{} = user, institution) do
    {communities, global_access?} = community_scope(user, institution)

    dynamic(false)
    |> or_global(global_access?)
    |> or_author(author_of(user))
    |> or_institution(institution)
    |> or_community_product(communities)
  end

  defp product_visibility(actor, institution), do: project_scoped_visibility(actor, institution)

  defp section_entitlement(%Author{} = author) do
    if Accounts.is_admin?(author), do: dynamic(true), else: dynamic(false)
  end

  defp section_entitlement(%User{id: user_id}) when is_integer(user_id) do
    dynamic([section: _section], exists(instructor_enrollment_query(user_id)))
  end

  defp section_entitlement(_actor), do: dynamic(false)

  defp or_global(condition, false), do: condition

  defp or_global(condition, true),
    do: dynamic([project: project], ^condition or project.visibility == :global)

  defp or_author(condition, nil), do: condition

  defp or_author(condition, %Author{id: author_id}) do
    dynamic(
      [project: project],
      ^condition or exists(project_author_query(author_id)) or
        (project.visibility == :selected and
           exists(project_visibility_query(:author_id, author_id)))
    )
  end

  defp or_institution(condition, %Institution{id: institution_id}) do
    dynamic(
      [project: project],
      ^condition or
        (project.visibility == :selected and
           exists(project_visibility_query(:institution_id, institution_id)))
    )
  end

  defp or_institution(condition, _institution), do: condition

  defp or_community_project(condition, []), do: condition

  defp or_community_project(condition, community_ids) do
    dynamic(
      [project: _project],
      ^condition or exists(community_project_query(community_ids))
    )
  end

  defp or_community_product(condition, []), do: condition

  defp or_community_product(condition, community_ids) do
    dynamic(
      [product: _product],
      ^condition or exists(community_product_query(community_ids))
    )
  end

  defp project_author_query(author_id) do
    from(author_project in Oli.Authoring.Authors.AuthorProject,
      where:
        author_project.project_id == parent_as(:project).id and
          author_project.author_id == ^author_id,
      select: 1
    )
  end

  defp project_visibility_query(:author_id, author_id) do
    from(visibility in ProjectVisibility,
      where:
        visibility.project_id == parent_as(:project).id and visibility.author_id == ^author_id,
      select: 1
    )
  end

  defp project_visibility_query(:institution_id, institution_id) do
    from(visibility in ProjectVisibility,
      where:
        visibility.project_id == parent_as(:project).id and
          visibility.institution_id == ^institution_id,
      select: 1
    )
  end

  defp community_project_query(community_ids) do
    from(visibility in CommunityVisibility,
      where:
        visibility.project_id == parent_as(:project).id and
          visibility.community_id in ^community_ids,
      select: 1
    )
  end

  defp community_product_query(community_ids) do
    from(visibility in CommunityVisibility,
      where:
        visibility.section_id == parent_as(:product).id and
          visibility.community_id in ^community_ids,
      select: 1
    )
  end

  defp instructor_enrollment_query(user_id) do
    from(enrollment in Enrollment,
      join: context_role in "enrollments_context_roles",
      on: context_role.enrollment_id == enrollment.id,
      where:
        enrollment.user_id == ^user_id and
          enrollment.section_id == parent_as(:section).id and
          enrollment.status == :enrolled and
          context_role.context_role_id in ^@instructor_context_role_ids,
      select: 1
    )
  end

  defp community_scope(%User{id: user_id}, institution) do
    communities = Groups.list_associated_communities(user_id, institution)

    global_access? =
      communities == [] or Enum.any?(communities, fn community -> community.global_access end)

    {Enum.map(communities, & &1.id), global_access?}
  end

  defp author_of(%User{author: %Author{} = author}), do: author
  defp author_of(%User{} = user), do: user |> Repo.preload(:author) |> Map.get(:author)
end
