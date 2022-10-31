defmodule Oli.Lti.AccessTokenLibrary do
  alias Oli.Lti.AccessTokenAdapter
  alias Lti_1p3.Tool.Services.AccessToken
  alias Oli.Lti.Tool.Registration

  @type access_token :: AccessTokenAdapter.access_token()

  @behaviour AccessTokenAdapter

  @doc """
    Mock implementation of the refresh adapter,
    the refresh operation is ran synchronously to simplify testing
  """
  @impl AccessTokenAdapter
  @spec fetch_access_token(%Registration{}, list(), String.t()) :: access_token
  def fetch_access_token(registration, scopes, host) do
    AccessToken.fetch_access_token(registration, scopes, host)
  end
end
