defmodule Oli.Delivery.Lti.OAuthParams do
  @moduledoc """
  OAuth Parameters
  """
  @enforce_keys [
    :oauth_callback,
    :oauth_consumer_key,
    :oauth_version,
    :oauth_nonce,
    :oauth_timestamp,
    :oauth_signature_method
  ]
  defstruct [
    :oauth_callback,
    :oauth_consumer_key,
    :oauth_version,
    :oauth_nonce,
    :oauth_timestamp,
    :oauth_signature_method
  ]
end
