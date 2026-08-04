defmodule OliWeb.PlaywrightSessionController do
  @moduledoc """
  Test-only browser session helpers used by Playwright scenario-driven tests.
  """

  use OliWeb, :controller

  alias Oli.Accounts
  alias OliWeb.UserAuth

  @doc """
  Creates a browser session for a seeded user and redirects to a validated local path.
  """
  @spec log_in_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def log_in_user(conn, params) do
    with :ok <- authorize(conn, params),
         {:ok, user} <- fetch_user(params) do
      redirect_path = build_redirect_path(params["request_path"]) || ~p"/"

      conn
      |> UserAuth.create_session(user)
      |> redirect(to: redirect_path)
    else
      {:error, :unauthorized} ->
        send_resp(conn, :unauthorized, "unauthorized")

      {:error, :user_not_found} ->
        send_resp(conn, :not_found, "user_not_found")
    end
  end

  defp authorize(conn, _params) do
    token = Application.get_env(:oli, :playwright_scenario_token)
    provided = List.first(get_req_header(conn, "x-playwright-scenario-token"))

    if valid_token?(token, provided) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp fetch_user(%{"email" => email}) when is_binary(email) and email != "" do
    case Accounts.get_user_by(email: email) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp fetch_user(_params), do: {:error, :user_not_found}

  defp build_redirect_path(path) when is_binary(path) do
    if valid_local_path?(path), do: path, else: nil
  end

  defp build_redirect_path(_), do: nil

  defp valid_token?(expected, provided) when is_binary(expected) and is_binary(provided) do
    Plug.Crypto.secure_compare(provided, expected)
  end

  defp valid_token?(_, _), do: false

  defp valid_local_path?(path) when is_binary(path) do
    uri = URI.parse(path)

    String.starts_with?(path, "/") and
      not String.starts_with?(path, "//") and
      not String.contains?(path, "\\") and
      not String.match?(path, ~r/[\x00-\x1F\x7F]/) and
      is_nil(uri.scheme) and
      is_nil(uri.host) and
      is_binary(uri.path) and
      String.starts_with?(uri.path, "/")
  end

  defp valid_local_path?(_), do: false
end
