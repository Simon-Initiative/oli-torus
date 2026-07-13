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

  defp authorize(conn, params) do
    token = Application.get_env(:oli, :playwright_scenario_token)
    provided = List.first(get_req_header(conn, "x-playwright-scenario-token")) || params["token"]

    if not is_nil(token) and provided == token do
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

  defp valid_local_path?("/" <> rest), do: rest != "" and not String.starts_with?(rest, "/")
  defp valid_local_path?(_), do: false
end
