defmodule Oli.Lti.AccessTokenAdapter do
  alias Oli.Lti.Tool.Registration
  alias Lti_1p3.Tool.Services.AccessToken

  @moduledoc """
    Behaviour to generate a function that returns an access token:
  """

  @type access_token :: {:ok, %AccessToken{}} | {:error, String.t()}

  @doc """
  Defines a callback to be used by access token adapters
  """
  @callback fetch_access_token(%Registration{}, list(), String.t()) :: access_token
end
