defmodule OliWeb.LiveSessionPlugs.AnalyticsPageViewTest do
  use OliWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    original = Application.fetch_env(:oli, :analytics)
    Application.put_env(:oli, :analytics, gtm_container_id: "GTM-QA123")

    on_exit(fn ->
      case original do
        :error -> Application.delete_env(:oli, :analytics)
        {:ok, value} -> Application.put_env(:oli, :analytics, value)
      end
    end)

    :ok
  end

  defp browser_context(page_path, extra \\ %{}) do
    Map.merge(
      %{
        "page_path" => page_path,
        "page_area" => "public",
        "page_title" => "Torus",
        "traffic_type" => "external"
      },
      extra
    )
  end

  defp with_context(conn, context) do
    put_connect_params(conn, %{"analytics_enabled" => true, "analytics_context" => context})
  end

  test "initial connected mount and same-route patches do not push page views", %{conn: conn} do
    {:ok, view, _} = live(with_context(conn, browser_context("/users/log_in")), "/users/log_in")
    refute_push_event(view, "analytics:page_view", %{})
    render_patch(view, "/users/log_in?tab=private&search=secret")
    refute_push_event(view, "analytics:page_view", %{})
  end

  test "fresh navigation mount pushes only the new route template", %{conn: conn} do
    {:ok, view, _} = live(with_context(conn, browser_context("/users/register")), "/users/log_in")

    assert_push_event(view, "analytics:page_view", %{
      page_path: "/users/log_in",
      page_area: "public",
      page_title: "Torus",
      traffic_type: "external"
    })

    render_patch(view, "/users/log_in?tab=private")
    refute_push_event(view, "analytics:page_view", %{})
  end

  test "a changed context on the same route template is pushed once", %{conn: conn} do
    stale = browser_context("/users/log_in", %{"user_role" => "learner", "course_id" => 42})
    {:ok, view, _} = live(with_context(conn, stale), "/users/log_in")

    assert_push_event(view, "analytics:page_view", context)

    assert context == %{
             page_path: "/users/log_in",
             page_area: "public",
             page_title: "Torus",
             traffic_type: "external"
           }

    render_patch(view, "/users/log_in?tab=private")
    refute_push_event(view, "analytics:page_view", %{})
  end

  test "LiveView navigation to another view in the live session pushes once", %{conn: conn} do
    {:ok, view, _} = live(with_context(conn, browser_context("/users/log_in")), "/users/log_in")
    refute_push_event(view, "analytics:page_view", %{})
    {:ok, next_view, _} = live_redirect(view, to: "/users/register")
    assert_push_event(next_view, "analytics:page_view", %{page_path: "/users/register"})
    render_patch(next_view, "/users/register?tab=private&search=secret")
    refute_push_event(next_view, "analytics:page_view", %{})
  end

  test "disabled deployment and excluded browser roots do not push", %{conn: conn} do
    conn = put_connect_params(conn, %{"analytics_enabled" => false})
    {:ok, view, _} = live(conn, "/users/log_in")
    refute_push_event(view, "analytics:page_view", %{})

    Application.put_env(:oli, :analytics, gtm_container_id: nil)
    {:ok, view, _} = live(with_context(conn, nil), "/users/log_in")
    refute_push_event(view, "analytics:page_view", %{})
  end
end
