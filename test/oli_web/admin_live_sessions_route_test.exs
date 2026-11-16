defmodule OliWeb.AdminLiveSessionsRouteTest do
  use ExUnit.Case, async: true

  # Router plugs only run on HTTP requests, so live navigation within a
  # live_session skips them. Every admin LiveView must therefore live in a
  # live_session whose on_mount hook re-checks the same role as its pipeline.

  @pipeline_hooks [
    require_authenticated_system_admin:
      {:system_admin, {OliWeb.AuthorAuth, :ensure_system_admin}},
    require_authenticated_account_admin:
      {:account_admin, {OliWeb.AuthorAuth, :ensure_account_admin}},
    require_authenticated_admin: {:admin, {OliWeb.AuthorAuth, :ensure_admin}}
  ]

  # Phoenix LiveDashboard declares its own live_session and is guarded by the
  # system admin pipeline.
  @excluded_prefixes ["/admin/dashboard"]

  test "every /admin LiveView route enforces its pipeline role through its live_session" do
    routes = admin_live_routes()

    assert routes != []

    for route <- routes do
      %{pipe_through: pipe_through} =
        Phoenix.Router.route_info(OliWeb.Router, "GET", concrete_path(route.path), "")

      {expected_session, expected_hook} = expected_for(pipe_through, route.path)
      {_live_view, _action, _opts, live_session} = route.metadata.phoenix_live_view
      hooks = Enum.map(Map.get(live_session.extra, :on_mount, []), & &1.id)

      assert live_session.name == expected_session,
             "#{route.path} is in live_session #{inspect(live_session.name)}, " <>
               "expected #{inspect(expected_session)}"

      assert expected_hook in hooks,
             "#{route.path} live_session does not run #{inspect(expected_hook)}"
    end
  end

  defp admin_live_routes do
    OliWeb.Router.__routes__()
    |> Enum.filter(fn route ->
      Map.has_key?(route.metadata, :phoenix_live_view) and
        String.starts_with?(route.path, "/admin") and
        not Enum.any?(@excluded_prefixes, &String.starts_with?(route.path, &1))
    end)
  end

  # The most restrictive role pipeline wins, since nested scopes accumulate pipelines.
  defp expected_for(pipe_through, path) do
    case Enum.find(@pipeline_hooks, fn {pipeline, _} -> pipeline in pipe_through end) do
      {_pipeline, expected} -> expected
      nil -> flunk("#{path} is not behind an admin role pipeline: #{inspect(pipe_through)}")
    end
  end

  defp concrete_path(path), do: String.replace(path, ~r/:[^\/]+/, "1")
end
