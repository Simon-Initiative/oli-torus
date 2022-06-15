defmodule OliWeb.ActivityManageController do
  use OliWeb, :controller
  alias OliWeb.Common.{Breadcrumb}
  alias Oli.Activities

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    registered_activities =
      Enum.sort_by(Activities.list_activity_registrations(), & &1.title, :asc)

    params = %{
      registered_activities: registered_activities,
      breadcrumbs: root_breadcrumbs()
    }

    render(
      %{conn | assigns: Map.merge(conn.assigns, params)},
      "index.html",
      Keyword.put_new([title: "Manage Activities"], :active, :activity_manage)
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

  def make_globally_visible(conn, %{"activity_slug" => activity_slug}) do
    case Activities.set_global_visibility(activity_slug, true) do
      {:ok, _} ->
        redirect(conn, to: Routes.activity_manage_path(conn, :index))

      {:error, message} ->
        conn
        |> put_flash(
          :error,
          "We couldn't switch registered activity to globally visible. #{message}"
        )
        |> redirect(to: Routes.activity_manage_path(conn, :index))
    end
  end

  def make_admin_visible(conn, %{"activity_slug" => activity_slug}) do
    case Activities.set_global_visibility(activity_slug, false) do
      {:ok, _} ->
        redirect(conn, to: Routes.activity_manage_path(conn, :index))

      {:error, message} ->
        conn
        |> put_flash(
          :error,
          "We couldn't switch registered activity to admin only visible. #{message}"
        )
        |> redirect(to: Routes.activity_manage_path(conn, :index))
    end
  end

  def root_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Manage Activities",
          link: Routes.activity_manage_path(OliWeb.Endpoint, :index)
        })
      ]
  end
end
