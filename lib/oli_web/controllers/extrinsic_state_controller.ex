defmodule OliWeb.ExtrinsicStateController do
  @moduledoc """
  Provides user state service endpoints for extrinsic state.
  """
  use OliWeb, :controller

  alias Oli.Delivery.ExtrinsicState

  def read_global(conn, params) do
    user = conn.assigns.current_user

    keys =
      case Map.get(params, "keys") do
        nil -> nil
        k -> MapSet.new(k)
      end

    case ExtrinsicState.read_global(user.sub, keys) do
      {:ok, state} ->
        json(conn, state)

      _ ->
        error(conn, 404, "not found")
    end
  end

  def upsert_global(conn, %{"key_values" => key_values}) do
    user = conn.assigns.current_user

    case ExtrinsicState.upsert_global(user.sub, key_values) do
      {:ok, _} ->
        json(conn, %{"result" => "success"})

      _ ->
        error(conn, 404, "not found")
    end
  end

  def delete_global(conn, params) do
    user = conn.assigns.current_user

    case Map.get(params, "keys") do
      nil ->
        error(conn, 400, "missing keyspec")

      k ->
        case ExtrinsicState.delete_global(user.sub, MapSet.new(k)) do
          {:ok, _} ->
            json(conn, %{"result" => "success"})

          _ ->
            error(conn, 404, "not found")
        end
    end
  end

  def read_section(conn, _params) do
  end

  def upsert_section(conn, _params) do
  end

  def delete_section(conn, _params) do
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end
