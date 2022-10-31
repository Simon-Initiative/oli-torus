defmodule Oli.Lti.AccessTokenAdapter do
  alias Oli.Lti.Tool.Registration
  alias Lti_1p3.Tool.Services.AccessToken

  @moduledoc """
    Behaviour for spawning a function that freshes the part_mapping materialized view:
  """

  @type access_token :: {:ok, %AccessToken{}} | {:error, String.t()}

  @doc """
  Defines a callback to be used by refresh adapters
  """
  @callback fetch_access_token(%Registration{}, list(), String.t()) :: access_token
end
