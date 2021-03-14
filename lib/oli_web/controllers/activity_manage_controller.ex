defmodule OliWeb.ActivityManageController do
  use OliWeb, :controller

  alias Oli.Activities

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    registered_activities =
      Enum.sort_by(Activities.list_activity_registrations(), & &1.globally_available, :desc)

    params = %{
      registered_activities: registered_activities
    }

    render(
      %{conn | assigns: Map.merge(conn.assigns, params)},
      "index.html",
      Keyword.put_new([title: "Manage"], :active, :activity_manage)
    )
  end

  def make_global(conn, %{"activity_slug" => activity_slug}) do
    case Activities.set_global_status(activity_slug, true) do
      {:ok, _} ->
        redirect(conn, to: Routes.activity_manage_path(conn, :index))

      {:error, message} ->
        conn
        |> put_flash(
          :error,
          "We couldn't switch registered activity to globally available. #{message}"
        )
        |> redirect(to: Routes.activity_manage_path(conn, :index))
    end
  end

  def make_private(conn, %{"activity_slug" => activity_slug}) do
    case Activities.set_global_status(activity_slug, false) do
      {:ok, _} ->
        redirect(conn, to: Routes.activity_manage_path(conn, :index))

      {:error, message} ->
        conn
        |> put_flash(
          :error,
          "We couldn't switch registered activity to privately available. #{message}"
        )
        |> redirect(to: Routes.activity_manage_path(conn, :index))
    end
  end
end
