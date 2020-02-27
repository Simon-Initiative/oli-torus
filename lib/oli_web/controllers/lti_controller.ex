defmodule OliWeb.LtiController do
  use OliWeb, :controller

  import Oli.Lti.Provider

  def basic_launch(conn, _params) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    scheme = System.get_env("LTI_PROTOCOL", scheme)
    port = if conn.port == 80 or conn.port == 443, do: "", else: ":#{conn.port}"
    url = "#{scheme}://#{conn.host}#{port}/lti/basic_launch"
    method = conn.method
    body_params = map_to_keyword_list(conn.body_params)
    # TODO: Load this shared_secret using the oauth_consumer_key param
    shared_secret = "secret"
    case validate_request(url, method, body_params, shared_secret) do
      { :ok } ->
          IO.puts("it works")
          render(conn, "basic_launch.html")
      { :invalid, reason } -> render(conn, "basic_launch_invalid.html", reason: reason)
      { :error, error } -> render(conn, "basic_launch_error.html", error: error)
    end
  end

  defp map_to_keyword_list(map) do
    Enum.map(map, fn({key, value}) -> {String.to_atom(key), value} end)
  end

end
