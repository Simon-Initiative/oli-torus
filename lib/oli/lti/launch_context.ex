defmodule Oli.Lti.LaunchContext do
  @moduledoc """
  Normalized in-request launch context used for immediate post-launch routing.
  """

  alias Oli.Lti.LtiParams

  @context_claim "https://purl.imsglobal.org/spec/lti/claim/context"
  @deployment_claim "https://purl.imsglobal.org/spec/lti/claim/deployment_id"
  @launch_presentation_claim "https://purl.imsglobal.org/spec/lti/claim/launch_presentation"
  @message_type_claim "https://purl.imsglobal.org/spec/lti/claim/message_type"
  @resource_link_claim "https://purl.imsglobal.org/spec/lti/claim/resource_link"
  @roles_claim "https://purl.imsglobal.org/spec/lti/claim/roles"
  @target_link_uri_claim "https://purl.imsglobal.org/spec/lti/claim/target_link_uri"

  @enforce_keys [:issuer, :client_id, :context_id, :roles]
  defstruct [
    :issuer,
    :client_id,
    :deployment_id,
    :context_id,
    :resource_link_id,
    :sub,
    :target_link_uri,
    :launch_presentation,
    :message_type,
    roles: []
  ]

  @type t :: %__MODULE__{}

  @spec from_claims(map()) :: {:ok, t()} | {:error, :missing_context}
  def from_claims(claims) do
    case get_in(claims, [@context_claim, "id"]) do
      context_id when is_binary(context_id) and context_id != "" ->
        {:ok,
         %__MODULE__{
           issuer: claims["iss"],
           client_id: LtiParams.peek_client_id(claims),
           deployment_id: claims[@deployment_claim],
           context_id: context_id,
           resource_link_id: get_in(claims, [@resource_link_claim, "id"]),
           sub: claims["sub"],
           target_link_uri: claims[@target_link_uri_claim],
           launch_presentation: claims[@launch_presentation_claim] || %{},
           message_type: claims[@message_type_claim],
           roles: claims[@roles_claim] || []
         }}

      _ ->
        {:error, :missing_context}
    end
  end

  @spec embedded?(t()) :: boolean()
  def embedded?(%__MODULE__{launch_presentation: %{"document_target" => "iframe"}}), do: true
  def embedded?(_context), do: false
end
