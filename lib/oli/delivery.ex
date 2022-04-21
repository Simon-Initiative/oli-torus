defmodule Oli.Delivery do
  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.Services.{AGS, NRPS}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Institutions
  alias Oli.Publishing
  alias Oli.Repo

  @deployment_claims "https://purl.imsglobal.org/spec/lti/claim/deployment_id"
  @context_claims "https://purl.imsglobal.org/spec/lti/claim/context"
  @roles_claims "https://purl.imsglobal.org/spec/lti/claim/roles"

  def retrieve_visible_sources(user, lti_params) do
    {institution, _registration, _deployment} =
      Institutions.get_institution_registration_deployment(
        lti_params["iss"],
        lti_params["aud"],
        lti_params[@deployment_claims])

    Publishing.retrieve_visible_sources(user, institution)
  end

  def create_section(source_id, user, lti_params) do
    # guard against creating a new section if one already exists
    case Sections.get_section_from_lti_params(lti_params) do
      nil ->
        {institution, _registration, deployment} =
          Institutions.get_institution_registration_deployment(
            lti_params["iss"],
            lti_params["aud"],
            lti_params[@deployment_claims]
          )

        # create section, section resources and enroll instructor
        {create_fn, id} =
          case source_id do
            "publication:" <> publication_id ->
              {&create_from_publication/5, String.to_integer(publication_id)}

            "product:" <> product_id ->
              {&create_from_product/5, String.to_integer(product_id)}
          end
        create_fn.(id, user, institution, lti_params, deployment)

      section ->
        # a section already exists, redirect to index
        {:ok, section}
    end
  end

  defp create_from_product(product_id, user, institution, lti_params, deployment) do
    Repo.transaction(fn ->
      blueprint = Oli.Delivery.Sections.get_section!(product_id)

      # calculate a cost, if an error, fallback to the amount in the blueprint
      # TODO: we may need to move this to AFTER a remix if the cost calculation factors
      # in the percentage project usage
      amount =
        case Oli.Delivery.Paywall.calculate_product_cost(blueprint, institution) do
          {:ok, amount} -> amount
          _ -> blueprint.amount
        end

      {:ok, section} =
        Oli.Delivery.Sections.Blueprint.duplicate(blueprint, %{
          type: :enrollable,
          timezone: institution.timezone,
          title: lti_params[@context_claims]["title"],
          context_id: lti_params[@context_claims]["id"],
          institution_id: institution.id,
          lti_1p3_deployment_id: deployment.id,
          blueprint_id: blueprint.id,
          amount: amount,
          grade_passback_enabled: AGS.grade_passback_enabled?(lti_params),
          line_items_service_url: AGS.get_line_items_url(lti_params),
          nrps_enabled: NRPS.nrps_enabled?(lti_params),
          nrps_context_memberships_url: NRPS.get_context_memberships_url(lti_params)
        })
      enroll(user.id, section.id, lti_params)

      section
    end)
  end

  defp create_from_publication(publication_id, user, institution, lti_params, deployment) do
    Repo.transaction(fn ->
      publication = Publishing.get_publication!(publication_id)

      {:ok, section} =
        Sections.create_section(%{
          type: :enrollable,
          timezone: institution.timezone,
          title: lti_params[@context_claims]["title"],
          context_id: lti_params[@context_claims]["id"],
          institution_id: institution.id,
          base_project_id: publication.project_id,
          lti_1p3_deployment_id: deployment.id,
          grade_passback_enabled: AGS.grade_passback_enabled?(lti_params),
          line_items_service_url: AGS.get_line_items_url(lti_params),
          nrps_enabled: NRPS.nrps_enabled?(lti_params),
          nrps_context_memberships_url: NRPS.get_context_memberships_url(lti_params)
        })
      {:ok, %Section{}} = Sections.create_section_resources(section, publication)
      enroll(user.id, section.id, lti_params)

      section
    end)
  end

  defp enroll(user_id, section_id, lti_params) do
    # Enroll this user with their proper roles (instructor)
    lti_roles = lti_params[@roles_claims]
    context_roles = ContextRoles.get_roles_by_uris(lti_roles)
    Sections.enroll(user_id, section_id, context_roles)
  end
end
