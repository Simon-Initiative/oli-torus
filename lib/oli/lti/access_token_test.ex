defmodule Oli.Lti.AccessTokenTest do
  alias Oli.Lti.AccessTokenAdapter
  alias Lti_1p3.Tool.Services.AccessToken
  alias Oli.Lti.Tool.Registration

  @type access_token :: AccessTokenAdapter.access_token()

  @behaviour AccessTokenAdapter

  @doc """
    Mock implementation of the access token adapter,
    The operation returns a value for the access token to simplify testing.
  """
  @impl AccessTokenAdapter
  @spec fetch_access_token(%Registration{}, list(), String.t()) :: access_token
  def fetch_access_token(%Registration{client_id: "error"}, _, _) do
    {:error, "error fetching access token"}
  end

  def fetch_access_token(_, _, _) do
    {:ok,
     %AccessToken{
       access_token: "access_token",
       token_type: "token_type",
       expires_in: "expires_in",
       scope: "scope"
     }}
  end
end
