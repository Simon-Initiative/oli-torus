defmodule OliWeb.PlaywrightAuth do
  @moduledoc """
  Authorizes Playwright automation requests via the x-playwright-scenario-token
  header, compared in constant time against the configured
  `:playwright_scenario_token`.

  Shared by the Playwright-only endpoints (scenario runner, private test
  assets), which exist solely when `:enable_playwright_scenarios` is set.
  """

  import Plug.Conn, only: [get_req_header: 2]

  @spec authorize(Plug.Conn.t()) :: :ok | {:error, :unauthorized}
  def authorize(conn) do
    expected = Application.get_env(:oli, :playwright_scenario_token)

    with [provided] <- get_req_header(conn, "x-playwright-scenario-token"),
         true <- is_binary(expected) and expected != "",
         true <- Plug.Crypto.secure_compare(provided, expected) do
      :ok
    else
      _ -> {:error, :unauthorized}
    end
  end
end
