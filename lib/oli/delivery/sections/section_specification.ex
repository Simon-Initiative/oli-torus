defmodule Oli.Delivery.Sections.SectionSpecification do
  alias Oli.Delivery.Sections.SectionSpecification
  alias Oli.Lti.LaunchIdentity
  alias Oli.Lti.LtiParams
  alias Oli.Institutions
  alias Lti_1p3.Tool.Services.{AGS, NRPS}

  defmodule Lti do
    @moduledoc """
    LTI details for section creation.

    `identity` is the validated `Oli.Lti.LaunchIdentity` of the launch this section is
    bound to. The authorization boundary sets it when it rebuilds the specification from
    the launch it authorized; a specification that has not been through the boundary
    cannot be applied.
    """
    @enforce_keys [:lti_params, :institution, :registration, :deployment]

    defstruct [
      :lti_params,
      :institution,
      :registration,
      :deployment,
      :identity
    ]
  end

  defmodule Direct do
    @moduledoc """
    Direct delivery for section creation.
    """
    defstruct []
  end

  @deployment_claims "https://purl.imsglobal.org/spec/lti/claim/deployment_id"

  @doc """
  Creates a specification for an LTI section based on the user and context ID.
  """
  def lti(user, context_id) do
    %LtiParams{params: lti_params} =
      LtiParams.get_lti_params_for_user_context(user.id, context_id)

    issuer = lti_params["iss"]
    client_id = LtiParams.peek_client_id(lti_params)
    deployment_id = lti_params[@deployment_claims]

    {institution, registration, deployment} =
      case Institutions.get_institution_registration_deployment(issuer, client_id, deployment_id) do
        nil ->
          {nil, nil, nil}

        {institution, registration, deployment} ->
          {institution, registration, deployment}
      end

    %SectionSpecification.Lti{
      lti_params: lti_params,
      institution: institution,
      registration: registration,
      deployment: deployment
    }
  end

  @doc """
  Creates a specification for a direct delivery section.
  """
  def direct(), do: %SectionSpecification.Direct{}

  @doc """
  Applies the section specification to the given section parameters.
  """
  def apply(
        section_params,
        %SectionSpecification.Lti{
          lti_params: lti_params,
          institution: institution,
          registration: registration,
          deployment: deployment,
          identity: %LaunchIdentity{context_id: context_id}
        }
      ),
      do:
        section_params
        |> Map.merge(%{
          open_and_free: false,
          context_id: context_id,
          institution_id: institution.id,
          lti_1p3_deployment_id: deployment.id,
          grade_passback_enabled: AGS.grade_passback_enabled?(lti_params),
          line_items_service_url: AGS.get_line_items_url(lti_params, registration),
          nrps_enabled: NRPS.nrps_enabled?(lti_params),
          nrps_context_memberships_url: NRPS.get_context_memberships_url(lti_params)
        })

  def apply(section_params, %SectionSpecification.Direct{}),
    do:
      section_params
      |> Map.merge(%{open_and_free: true})

  @doc """
  Returns the institution associated with the section specification.
  """
  def get_institution(%SectionSpecification.Lti{institution: institution}),
    do: institution

  def get_institution(_section_spec), do: nil
end
