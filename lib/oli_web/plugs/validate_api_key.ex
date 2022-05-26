# Plug to check for a valid api key in an Authorization header
# To use, specify the function to validate the key against. Examples:
#
#  plug(Oli.Plugs.ValidateAPIKey, &Oli.Interop.validate_for_automation_setup/1)
#  plug(Oli.Plugs.ValidateAPIKey, &Oli.Interop.validate_for_payments/1)
#  plug(Oli.Plugs.ValidateAPIKey, &Oli.Interop.validate_for_registration/1)
#

defmodule Oli.Plugs.ValidateAPIKey do
  def init(opts) do
    unless is_nil(opts) do
      opts
    else
      &Oli.Interop.validate_for_automation_setup/1
    end
  end

  def call(conn, opts) do
    if OliWeb.Api.Helpers.is_valid_api_key?(conn, opts) do
      conn
    else
      conn
      |> Plug.Conn.resp(403, "Invalid API key")
      |> Plug.Conn.halt()
    end
  end
end
