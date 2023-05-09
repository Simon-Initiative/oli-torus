defmodule Oli.Delivery do
  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.Services.{AGS, NRPS}
  alias Oli.Delivery.{DeliverySetting, Sections}
  alias Oli.Delivery.Sections.{Section, SectionsProjectsPublications}
  alias Oli.Institutions
  alias Oli.Lti.LtiParams
  alias Oli.Publishing
  alias Oli.Repo
  alias Oli.Publishing.{DeliveryResolver, PublishedResource}
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, ActivityAttempt, ResourceAccess}

  import Ecto.Query, warn: false
  import Oli.Utils

  @deployment_claims "https://purl.imsglobal.org/spec/lti/claim/deployment_id"
  @context_claims "https://purl.imsglobal.org/spec/lti/claim/context"
  @roles_claims "https://purl.imsglobal.org/spec/lti/claim/roles"

  def retrieve_visible_sources(user, lti_params) do
    {institution, _registration, _deployment} =
      Institutions.get_institution_registration_deployment(
        lti_params["iss"],
        LtiParams.peek_client_id(lti_params),
        lti_params[@deployment_claims]
      )

    Publishing.retrieve_visible_sources(user, institution)
  end

  def create_section(source_id, user, lti_params, attrs \\ %{}) do
    # guard against creating a new section if one already exists
    case Sections.get_section_from_lti_params(lti_params) do
      nil ->
        {institution, registration, deployment} =
          Institutions.get_institution_registration_deployment(
            lti_params["iss"],
            LtiParams.peek_client_id(lti_params),
            lti_params[@deployment_claims]
          )

        # create section, section resources and enroll instructor
        {create_fn, id} =
          case source_id do
            "publication:" <> publication_id ->
              {&create_from_publication/7, String.to_integer(publication_id)}

            "product:" <> product_id ->
              {&create_from_product/7, String.to_integer(product_id)}
          end

        create_fn.(id, user, institution, lti_params, deployment, registration, attrs)

      section ->
        # a section already exists, redirect to index
        {:ok, section}
    end
  end

  defp create_from_product(
         product_id,
         user,
         institution,
         lti_params,
         deployment,
         registration,
         attrs \\ %{}
       ) do
    Repo.transaction(fn ->
      blueprint = Oli.Delivery.Sections.get_section!(product_id)

      # calculate a cost, if an error, fallback to the amount in the blueprint
      # TODO: we may need to move this to AFTER a remix if the cost calculation factors
      # in the percentage project usage
      amount =
        case Oli.Delivery.Paywall.section_cost_from_product(blueprint, institution) do
          {:ok, amount} -> amount
          _ -> blueprint.amount
        end

      project = Oli.Repo.get(Oli.Authoring.Course.Project, blueprint.base_project_id)

      {:ok, section} =
        Oli.Delivery.Sections.Blueprint.duplicate(
          blueprint,
          Map.merge(
            %{
              type: :enrollable,
              title: lti_params[@context_claims]["title"],
              context_id: lti_params[@context_claims]["id"],
              institution_id: institution.id,
              lti_1p3_deployment_id: deployment.id,
              blueprint_id: blueprint.id,
              has_experiments: project.has_experiments,
              amount: amount,
              pay_by_institution: blueprint.pay_by_institution,
              grade_passback_enabled: AGS.grade_passback_enabled?(lti_params),
              line_items_service_url: AGS.get_line_items_url(lti_params, registration),
              nrps_enabled: NRPS.nrps_enabled?(lti_params),
              nrps_context_memberships_url: NRPS.get_context_memberships_url(lti_params)
            },
            attrs
          )
        )

      {:ok, _} = Sections.rebuild_contained_pages(section)

      enroll(user.id, section.id, lti_params)

      section
    end)
  end

  defp create_from_publication(
         publication_id,
         user,
         institution,
         lti_params,
         deployment,
         registration,
         attrs \\ %{}
       ) do
    Repo.transaction(fn ->
      publication = Publishing.get_publication!(publication_id) |> Repo.preload(:project)

      customizations =
        case publication.project.customizations do
          nil -> nil
          labels -> Map.from_struct(labels)
        end

      {:ok, section} =
        Sections.create_section(
          Map.merge(
            %{
              type: :enrollable,
              title: lti_params[@context_claims]["title"],
              context_id: lti_params[@context_claims]["id"],
              institution_id: institution.id,
              base_project_id: publication.project_id,
              has_experiments: publication.project.has_experiments,
              lti_1p3_deployment_id: deployment.id,
              grade_passback_enabled: AGS.grade_passback_enabled?(lti_params),
              line_items_service_url: AGS.get_line_items_url(lti_params, registration),
              nrps_enabled: NRPS.nrps_enabled?(lti_params),
              nrps_context_memberships_url: NRPS.get_context_memberships_url(lti_params),
              customizations: customizations
            },
            attrs
          )
        )

      {:ok, %Section{} = section} = Sections.create_section_resources(section, publication)
      {:ok, _} = Sections.rebuild_contained_pages(section)

      enroll(user.id, section.id, lti_params)
      {:ok, updated_section} = maybe_update_section_contains_explorations(section)

      updated_section
    end)
  end

  defp enroll(user_id, section_id, lti_params) do
    # Enroll this user with their proper roles (instructor)
    lti_roles = lti_params[@roles_claims]
    context_roles = ContextRoles.get_roles_by_uris(lti_roles)
    Sections.enroll(user_id, section_id, context_roles)
  end

  # ------------------------------------------------------------
  # Delivery Settings

  @doc """
  Returns the list of delivery settings that meets the criteria passed in the filter.

  ## Examples

      iex> search_delivery_settings(%{section_id: 1, resource_id: 1})
      [%Post{section_id: 1, resource_id: 1}, ...]

      iex> search_delivery_settings(%{resource_id: 123})
      []
  """
  def search_delivery_settings(filter) do
    from(ds in DeliverySetting, where: ^filter_conditions(filter))
    |> Repo.all()
  end

  @doc """
  Creates a delivery setting.

  ## Examples

      iex> create_delivery_setting(%{field: new_value})
      {:ok, %DeliverySetting{}}

      iex> create_delivery_setting(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_delivery_setting(attrs \\ %{}) do
    %DeliverySetting{}
    |> DeliverySetting.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a delivery setting that meets the criteria passed in the clauses.

  ## Examples

      iex> get_delivery_setting_by(%{id: 1})
      %DeliverySetting{}

      iex> get_delivery_setting_by(%{id: 123})
      nil
  """
  def get_delivery_setting_by(clauses),
    do: Repo.get_by(DeliverySetting, clauses)

  @doc """
  Updates a delivery setting.

  ## Examples

      iex> update_delivery_setting(delivery_setting, %{field: new_value})
      {:ok, %DeliverySetting{}}

      iex> update_delivery_setting(delivery_setting, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_delivery_setting(%DeliverySetting{} = delivery_setting, attrs) do
    delivery_setting
    |> DeliverySetting.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking delivery setting changes.

  ## Examples

      iex> change_delivery_setting(delivery_setting)
      %Ecto.Changeset{data: %DeliverySetting{}}
  """
  def change_delivery_setting(%DeliverySetting{} = delivery_setting, attrs \\ %{}) do
    DeliverySetting.changeset(delivery_setting, attrs)
  end

  @doc """
  Creates a new, or updates the existing delivery setting
  for the given section and resource.

  ## Examples

      iex> upsert_delivery_setting(%{field: new_value})
      {:ok, %DeliverySetting{}}

      iex> upsert_delivery_setting(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def upsert_delivery_setting(attrs) do
    section_id = attrs["section_id"] || attrs.section_id
    resource_id = attrs["resource_id"] || attrs.resource_id

    case get_delivery_setting_by(%{
           section_id: section_id,
           resource_id: resource_id
         }) do
      nil -> create_delivery_setting(attrs)
      ds -> update_delivery_setting(ds, attrs)
    end
  end

  defp contains_explorations(section_slug) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")

    Repo.one(
      from([sr: sr, rev: rev] in DeliveryResolver.section_resource_revisions(section_slug),
        where:
          rev.purpose == :application and rev.deleted == false and
            rev.resource_type_id == ^page_id,
        select: rev.id,
        limit: 1
      )
    )
    |> case do
      nil -> false
      _ -> true
    end
  end

  defp update_contains_explorations(section, value) do
    section
    |> Section.changeset(%{contains_explorations: value})
    |> Repo.update()
  end

  def maybe_update_section_contains_explorations(
        %Section{
          slug: section_slug,
          contains_explorations: contains_explorations
        } = section
      ) do
    case {contains_explorations(section_slug), contains_explorations} do
      {true, false} ->
        update_contains_explorations(section, true)

      {false, true} ->
        update_contains_explorations(section, false)

      _ ->
        {:ok, section}
    end
  end

  defp survey_resource_access(section_slug, user_id) do
    ResourceAccess
    |> join(:inner, [r], s in Section,
      on: r.section_id == s.id and r.resource_id == s.required_survey_resource_id
    )
    |> where(
      [r, s],
      r.section_id == s.id and r.user_id == ^user_id and s.slug == ^section_slug
    )
    |> select([r, s], %{
      resource_access_id: r.id,
      section_id: r.section_id,
      project_id: s.base_project_id
    })
    |> Repo.one()
  end

  def has_completed_survey?(section_slug, user_id) do
    case survey_resource_access(section_slug, user_id) do
      nil ->
        false

      %{
        section_id: section_id,
        project_id: project_id,
        resource_access_id: resource_access_id
      } ->
        SectionsProjectsPublications
        |> join(:inner, [spp], pr in PublishedResource,
          on: pr.publication_id == spp.publication_id
        )
        |> join(:inner, [_spp, pr], a_att in ActivityAttempt,
          on: a_att.revision_id == pr.revision_id
        )
        |> join(:inner, [_spp, _pr, a_att], r_att in ResourceAttempt,
          on: r_att.id == a_att.resource_attempt_id
        )
        |> join(:left, [_spp, _pr, _a_att, r_att], r_att_2 in ResourceAttempt,
          on: r_att_2.resource_access_id == r_att.resource_access_id and r_att.id < r_att_2.id
        )
        |> where(
          [spp, _pr, _a_att, r_att, r_att_2],
          spp.section_id == ^section_id and
            spp.project_id == ^project_id and
            r_att.resource_access_id == ^resource_access_id and
            is_nil(r_att_2)
        )
        |> group_by([_spp, _pr, a_att], [a_att.revision_id, a_att.lifecycle_state])
        |> select(
          [_spp, _pr, a_att, _r_att, _r_acc],
          {a_att.revision_id, a_att.lifecycle_state}
        )
        |> Repo.all()
        |> Enum.reduce(%{}, fn {revision_id, lifecycle_state}, acc ->
          if Map.get(acc, revision_id) == :evaluated do
            acc
          else
            Map.put(acc, revision_id, lifecycle_state)
          end
        end)
        |> Enum.all?(&(elem(&1, 1) == :evaluated))
    end
  end
end
