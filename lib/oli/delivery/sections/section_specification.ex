defmodule Oli.Delivery.Sections.SectionSpecification do
  alias Oli.Delivery.Sections.SectionSpecification
  alias Oli.Lti.LtiParams
  alias Oli.Institutions
  alias Lti_1p3.Tool.Services.{AGS, NRPS}

  defmodule Lti do
    @moduledoc """
    LTI details for section creation.
    """
    @enforce_keys [:lti_params, :institution, :registration, :deployment]

    defstruct [
      :lti_params,
      :institution,
      :registration,
      :deployment
    ]
  end

  defmodule Direct do
    @moduledoc """
    Direct delivery for section creation.
    """
    defstruct []
  end

  @deployment_claims "https://purl.imsglobal.org/spec/lti/claim/deployment_id"
  @context_claims "https://purl.imsglobal.org/spec/lti/claim/context"

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
          registration: _registration,
          deployment: deployment
        }
      ) do
    ags_settings = ags_settings_from_lti_params(lti_params)

    section_params
    |> Map.merge(%{
      open_and_free: false,
      context_id: lti_params[@context_claims]["id"],
      institution_id: institution.id,
      lti_1p3_deployment_id: deployment.id,
      grade_passback_enabled: ags_settings.grade_passback_enabled,
      line_items_service_url: ags_settings.line_items_service_url,
      nrps_enabled: NRPS.nrps_enabled?(lti_params),
      nrps_context_memberships_url: NRPS.get_context_memberships_url(lti_params)
    })
  end

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

  defp ags_settings_from_lti_params(lti_params) do
    case AGS.from_launch_claim(lti_params) do
      {:ok, endpoint} ->
        %{
          grade_passback_enabled: ags_grade_passback_enabled?(endpoint),
          line_items_service_url: endpoint.line_items_url
        }

      _ ->
        %{
          grade_passback_enabled: false,
          line_items_service_url: nil
        }
    end
  end

  defp ags_grade_passback_enabled?(endpoint) do
    has_line_items_url? = is_binary(endpoint.line_items_url) and endpoint.line_items_url != ""
    scopes = endpoint.scopes || []

    has_line_item_scope? = Enum.any?(AGS.required_scopes(:create_line_item), &(&1 in scopes))
    has_score_scope? = Enum.any?(AGS.required_scopes(:post_score), &(&1 in scopes))

    has_line_items_url? and has_line_item_scope? and has_score_scope?
  end
end
