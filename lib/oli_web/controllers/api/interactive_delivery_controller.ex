defmodule OliWeb.Api.InteractiveDeliveryController do
  @moduledoc "Authenticated transport for the versioned Interactive iframe capabilities."
  use OliWeb, :controller

  alias Oli.Interactives.Delivery

  @doc "Handles read-only bridge requests; GET can never save state or finalize results."
  def read(conn, params) do
    method = Map.get(params, "method", "context")

    case method in ["context", "attempt.get", "section.get"] do
      true ->
        execute(
          conn,
          Map.merge(params, %{
            "version" => 1,
            "method" => method,
            "params" => %{"key" => params["key"]}
          })
        )

      false ->
        conn |> put_status(405) |> json(%{error: %{code: "read_only"}})
    end
  end

  @doc "Dispatches one learner request bound to the route's section and attempt."
  def execute(conn, %{"section_slug" => slug, "activity_attempt_guid" => guid} = params) do
    case Delivery.execute(
           conn.assigns.current_user.id,
           slug,
           guid,
           params,
           get_session(conn, :datashop_session_id)
         ) do
      {:ok, result} ->
        json(conn, %{result: result})

      {:error, reason} ->
        status =
          case reason do
            :not_found -> 404
            :read_only -> 409
            :incomplete_parts -> 409
            _ -> 422
          end

        conn |> put_status(status) |> json(%{error: %{code: reason}})
    end
  end
end
