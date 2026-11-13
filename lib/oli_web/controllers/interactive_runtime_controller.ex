defmodule OliWeb.InteractiveRuntimeController do
  @moduledoc "Public static-runtime redirect; no learner state or user-selected storage URLs are exposed."
  use OliWeb, :controller

  @doc "Loads the shared platform runtime on the media origin for a public static bundle."
  def show(conn, %{"build_id" => id}) do
    case Oli.Interactives.Runtime.entry(id) do
      {:ok, url} ->
        conn |> put_resp_header("cache-control", "no-store") |> redirect(external: url)

      {:error, :invalid_bundle} ->
        send_resp(conn, 400, "Invalid interactive bundle")

      _ ->
        send_resp(
          conn,
          503,
          "The interactive runtime is temporarily unavailable. Reload to try again."
        )
    end
  end
end
