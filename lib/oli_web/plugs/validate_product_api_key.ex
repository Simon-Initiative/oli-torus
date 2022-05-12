defmodule Oli.Plugs.ValidateProductApiKey do
  import OliWeb.Api.Helpers

  def init(opts), do: opts

  def call(conn, _opts) do
    if is_valid_api_key?(conn, &Oli.Interop.validate_for_products/1) do
      conn
    else
      error(conn, 401, "Unauthorized")
    end
  end
end
