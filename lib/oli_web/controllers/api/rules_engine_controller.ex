defmodule OliWeb.Api.RulesEngineController do
  use OliWeb, :controller

  def execute(conn, %{"state" => state, "rules" => rules}) do
    case NodeJS.call({"rules", :check}, [state, rules]) do
      {:ok, result} -> json(conn, result)
      {:error, _} -> error(conn, 400, "bad request")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end
