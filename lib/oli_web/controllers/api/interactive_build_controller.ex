defmodule OliWeb.Api.InteractiveBuildController do
  use OliWeb, :controller
  alias Oli.Interactives.Builds

  @doc "Starts a build for an activity in the current author's project."
  def create(conn, %{"project" => project, "activity" => activity} = params) do
    with {id, ""} <- Integer.parse(activity),
         {:ok, _build} <- Builds.start(project, id, conn.assigns[:current_author], params),
         {:ok, response} <- Builds.latest(project, id, conn.assigns[:current_author]) do
      conn |> put_status(:accepted) |> json(response)
    else
      {:error, :not_authorized} ->
        conn |> put_status(:forbidden) |> json(%{message: "Unauthorized"})

      {:error, message} when is_binary(message) ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: message})

      _ ->
        conn |> put_status(:bad_request) |> json(%{message: "Invalid build request"})
    end
  end

  @doc "Returns the latest build status and canonical model when completed."
  def show(conn, %{"project" => project, "activity" => activity}) do
    with {id, ""} <- Integer.parse(activity),
         {:ok, response} <- Builds.latest(project, id, conn.assigns[:current_author]) do
      json(conn, response)
    else
      _ -> conn |> put_status(:forbidden) |> json(%{message: "Unauthorized"})
    end
  end

  @doc "Streams an authorized build's visible output, restoring saved history on reconnect."
  def events(conn, %{"project" => project, "activity" => activity, "build_id" => build_id}) do
    with {id, ""} <- Integer.parse(activity),
         {:ok, build} <- Builds.get(project, id, build_id, conn.assigns[:current_author]) do
      conn =
        conn
        |> put_resp_content_type("text/event-stream")
        |> put_resp_header("cache-control", "no-cache, no-transform")
        |> put_resp_header("x-accel-buffering", "no")
        |> send_chunked(200)

      Oli.Interactives.Progress.follow(build, conn, fn sink, event, data ->
        chunk(sink, "event: #{event}\ndata: #{Jason.encode!(data)}\n\n")
      end)
    else
      _ -> conn |> put_status(:forbidden) |> json(%{message: "Unauthorized"})
    end
  end

  @doc "Requests cancellation of exactly the selected build; completion is fenced immediately."
  def cancel(conn, %{
        "project" => project,
        "activity" => activity,
        "build_id" => build_id,
        "version" => 1
      }) do
    with {id, ""} <- Integer.parse(activity),
         {:ok, _} <- Builds.cancel(project, id, build_id, conn.assigns[:current_author]),
         {:ok, response} <- Builds.latest(project, id, conn.assigns[:current_author]) do
      conn |> put_status(:accepted) |> json(response)
    else
      {:error, :not_active} ->
        conn |> put_status(:conflict) |> json(%{message: "This session has already finished."})

      _ ->
        conn |> put_status(:forbidden) |> json(%{message: "Unauthorized"})
    end
  end

  def cancel(conn, _),
    do: conn |> put_status(:bad_request) |> json(%{message: "Invalid cancellation request"})
end
