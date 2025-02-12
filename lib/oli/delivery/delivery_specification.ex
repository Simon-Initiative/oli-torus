defmodule Oli.Delivery.DeliverySpecification do
  defmodule Lti do
    @moduledoc """
    LTI details for section creation.
    """
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

  alias Oli.Delivery.DeliverySpecification
  alias Oli.Lti.LtiParams
  alias Oli.Institutions
  alias Oli.Accounts.User

  @deployment_claims "https://purl.imsglobal.org/spec/lti/claim/deployment_id"
  @resource_link_claims "https://purl.imsglobal.org/spec/lti/claim/resource_link"
  @context_claims "https://purl.imsglobal.org/spec/lti/claim/context"

  def new(%User{id: user_id} = _user, :lti) do
    %LtiParams{params: lti_params} =
      LtiParams.get_latest_user_lti_params(user_id)

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

    %DeliverySpecification.Lti{
      lti_params: lti_params,
      institution: institution,
      registration: registration,
      deployment: deployment
    }
  end

  def new(_user, :direct), do: %DeliverySpecification.Direct{}

  @doc """
  Suggest a title for the section based on the LTI params. The title is suggested based on the
  following order of precedence:
    1. The title from the resource link claims
    2. The title from the context claims
  """
  def suggested_title(%DeliverySpecification.Lti{lti_params: lti_params}),
    do:
      get_in(lti_params, [@resource_link_claims, "title"]) ||
        get_in(lti_params, [@context_claims, "title"])

  def suggested_title(_), do: nil

  def get_institution(%DeliverySpecification.Lti{institution: institution}), do: institution
  def get_institution(_), do: nil
end
