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

  # This is an application storage limit, not a protocol limit.
  #
  # The columns these four values are written to are `varchar(255)`, which counts 255
  # *characters*; the bound here is 255 *bytes*, so it is stricter than the column and can
  # never produce a value the column cannot hold. Non-ASCII values are accepted while they
  # fit it.
  #
  # Only two of the four have a protocol limit to compare against: LTI 1.3 (§5.3.3, §5.4.1)
  # limits a deployment id and a context id to 255 ASCII characters, and this bound accepts
  # every identity that obeys it. An issuer and a client id have no such limit — OAuth
  # leaves client id size undefined — so for those two the bound is ours alone, chosen so
  # every field of the identity is storable by construction.
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

  # PostgreSQL rejects a NUL byte in any character type, and invalid UTF-8 never reaches a
  # column either — both raise out of the query rather than returning an error, so they are
  # refused here. This entry point takes arbitrary binaries, so neither is hypothetical.
  defp persistable?(value), do: String.valid?(value) and not String.contains?(value, <<0>>)
end
