defmodule OliWeb.Plugs.AllowIframeCSP do
  @moduledoc """
  Allows resources to be loaded in an iframe by modifying the Content Security Policy
  to include additional frame-ancestors beyond 'self'.

  This plug addresses the CSP restrictions introduced in Phoenix LiveView 1.1 that
  prevent iframes from loading from external origins.

  ## Options

  * `:allowed_origins` - List of additional origins to allow (default: ["*"])
  * `:allow_all` - Boolean to allow all origins with "*" (default: true)

  ## Examples

      # Allow all origins (default)
      plug(OliWeb.Plugs.AllowIframeCSP)

      # Allow specific origins only
      plug(OliWeb.Plugs.AllowIframeCSP, allowed_origins: ["https://example.com", "https://trusted-site.org"], allow_all: false)

      # Allow ngrok and other development domains
      plug(OliWeb.Plugs.AllowIframeCSP, allowed_origins: ["https://*.ngrok.io", "https://localhost:*"], allow_all: false)
  """

  import Plug.Conn

  def init(opts \\ %{}) do
    %{
      allowed_origins: Keyword.get(opts, :allowed_origins, ["*"]),
      allow_all: Keyword.get(opts, :allow_all, true)
    }
  end

  def call(conn, opts) do
    # Remove the X-Frame-Options header (legacy iframe protection)
    conn = delete_resp_header(conn, "x-frame-options")

    # Get the current CSP header if it exists
    current_csp = get_resp_header(conn, "content-security-policy")

    case current_csp do
      [] ->
        # No CSP header exists, so we don't need to modify anything
        conn

      [csp_value] ->
        # Modify the existing CSP to allow iframe embedding
        new_csp = modify_frame_ancestors(csp_value, opts)
        put_resp_header(conn, "content-security-policy", new_csp)

      multiple_values ->
        # Multiple CSP headers (shouldn't happen normally, but handle it)
        new_csp =
          multiple_values
          |> Enum.map(&modify_frame_ancestors(&1, opts))
          |> Enum.join("; ")

        put_resp_header(conn, "content-security-policy", new_csp)
    end
  end

  defp modify_frame_ancestors(csp_value, opts) do
    additional_origins = get_additional_origins(opts)

    # Check if frame-ancestors directive exists
    if String.contains?(csp_value, "frame-ancestors") do
      # Replace frame-ancestors 'self' with frame-ancestors 'self' plus additional origins
      String.replace(
        csp_value,
        ~r/frame-ancestors\s+[^;]*/,
        "frame-ancestors 'self' #{additional_origins}"
      )
    else
      # Add frame-ancestors directive if it doesn't exist
      csp_value <> "; frame-ancestors 'self' #{additional_origins}"
    end
  end

  defp get_additional_origins(%{allow_all: true}), do: "*"

  defp get_additional_origins(%{allowed_origins: origins}) do
    Enum.join(origins, " ")
  end
end
