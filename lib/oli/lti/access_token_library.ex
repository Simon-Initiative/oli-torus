defmodule Oli.Lti.AccessTokenLibrary do
  alias Oli.Lti.AccessTokenAdapter
  alias Lti_1p3.Tool.Services.AccessToken
  alias Oli.Lti.Tool.Registration

  @type access_token :: AccessTokenAdapter.access_token()

  @behaviour AccessTokenAdapter

  @doc """
    Mock implementation of the access token adapter,
    the fetch_access_token function of the lti_1p3 library is called to obtain an access token.
  """
  @impl AccessTokenAdapter
  @spec fetch_access_token(%Registration{}, list(), String.t()) :: access_token
  def fetch_access_token(registration, scopes, host) do
    AccessToken.fetch_access_token(registration, scopes, host)
  end
end
