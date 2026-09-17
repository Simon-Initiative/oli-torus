defmodule Oli.Lti.LaunchIdentity do
  @moduledoc """
  The identity of one LTI launch: the issuer, client, deployment and context that together
  name a single platform course.

  Every value a course section is bound to comes from here. Claims are validated once, at
  construction: anything missing, empty or not a string is refused, so no caller has to
  guard the individual claim shapes and none can be bound to a half-named launch.
  """

  alias Oli.Lti.LtiParams

  @context_claim "https://purl.imsglobal.org/spec/lti/claim/context"
  @deployment_claim "https://purl.imsglobal.org/spec/lti/claim/deployment_id"

  # A storage bound, in bytes, against `varchar(255)` columns that count characters:
  # stricter than the column, and wide enough for every protocol-compliant identity.
  @max_length 255

  @enforce_keys [:issuer, :client_id, :deployment_id, :context_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          issuer: String.t(),
          client_id: String.t(),
          deployment_id: String.t(),
          context_id: String.t()
        }

  @doc """
  Builds the identity of a launch from its claims, or `:error` if the claims do not name
  one completely, or name it with a value too long to persist.
  """
  @spec from_claims(term()) :: {:ok, t()} | :error
  def from_claims(
        %{@context_claim => %{"id" => context_id}, @deployment_claim => deployment_id} = claims
      ) do
    new(claims["iss"], LtiParams.peek_client_id(claims), deployment_id, context_id)
  end

  def from_claims(_claims), do: :error

  defp new(issuer, client_id, deployment_id, context_id)
       when is_binary(issuer) and issuer != "" and byte_size(issuer) <= @max_length and
              is_binary(client_id) and client_id != "" and byte_size(client_id) <= @max_length and
              is_binary(deployment_id) and deployment_id != "" and
              byte_size(deployment_id) <= @max_length and
              is_binary(context_id) and context_id != "" and
              byte_size(context_id) <= @max_length do
    if Enum.all?([issuer, client_id, deployment_id, context_id], &persistable?/1) do
      {:ok,
       %__MODULE__{
         issuer: issuer,
         client_id: client_id,
         deployment_id: deployment_id,
         context_id: context_id
       }}
    else
      :error
    end
  end

  defp new(_issuer, _client_id, _deployment_id, _context_id), do: :error

  # PostgreSQL rejects a NUL byte in any character type, and invalid UTF-8 raises out of
  # the query rather than returning an error.
  defp persistable?(value), do: String.valid?(value) and not String.contains?(value, <<0>>)
end
