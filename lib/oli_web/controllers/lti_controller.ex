defmodule OliWeb.LtiController do
  use OliWeb, :controller

  import Oli.Lti.Provider

  alias Oli.Repo
  alias Oli.Accounts.Institution

  def basic_launch(conn, _params) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    scheme = System.get_env("LTI_PROTOCOL", scheme)
    port = if conn.port == 80 or conn.port == 443, do: "", else: ":#{conn.port}"
    url = "#{scheme}://#{conn.host}#{port}/lti/basic_launch"
    method = conn.method
    body_params = map_to_keyword_list(conn.body_params)
    consumer_key = conn.body_params["oauth_consumer_key"]

    case Repo.get_by(Institution, consumer_key: consumer_key) do
      nil ->
        render(conn, "basic_launch_invalid.html", reason: "Institution with consumer_key '#{consumer_key}' does not exist")
      institution ->
        shared_secret = institution.shared_secret
        case validate_request(url, method, body_params, shared_secret) do
          { :ok } ->
              render(conn, "basic_launch.html", institution: institution)
          { :invalid, reason } -> render(conn, "basic_launch_invalid.html", reason: reason)
        end
    end
  end

  defp map_to_keyword_list(map) do
    Enum.map(map, fn({key, value}) -> {String.to_atom(key), value} end)
  end

end
