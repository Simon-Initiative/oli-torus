defmodule OliWeb.Analytics do
  @moduledoc "Sanitized, route-level analytics context. Never returns request paths or titles."

  alias Oli.Accounts

  @titles %{
    "delivery" => "Learning",
    "instructor" => "Instructor",
    "authoring" => "Authoring",
    "admin" => "Administration",
    "public" => "Torus"
  }

  @doc "Whether this deployment has opted into GTM."
  @spec enabled?() :: boolean()
  def enabled? do
    is_binary(Application.get_env(:oli, :analytics, [])[:gtm_container_id])
  end

  @doc "Resolves a GET URL to a Phoenix route template, or nil for unknown/excluded routes."
  @spec page_context(String.t(), map()) :: map() | nil
  def page_context(url, assigns \\ %{}) do
    %{host: host, path: path} = URI.parse(url)

    case Phoenix.Router.route_info(OliWeb.Router, "GET", path || "/", host || "localhost") do
      :error -> nil
      route_info -> context_for_route(route_info, assigns)
    end
  end

  @doc "Resolves sanitized page context from a root layout connection."
  @spec context_for_conn(Plug.Conn.t()) :: map() | nil
  def context_for_conn(conn) do
    case Phoenix.Router.route_info(OliWeb.Router, conn.method, conn.request_path, conn.host) do
      :error -> nil
      route_info -> context_for_route(route_info, conn.assigns)
    end
  end

  defp context_for_route(%{route: route} = info, assigns) do
    case excluded?(route, info) do
      true ->
        nil

      false ->
        area = page_area(route, info)

        %{
          page_path: route,
          page_area: area,
          page_title: Map.fetch!(@titles, area),
          traffic_type: traffic_type(assigns)
        }
    end
  end

  defp excluded?(route, info) do
    String.starts_with?(route, ["/lti", "/api/", "/mcp"]) or
      route == "/sections/:section_slug/payment/new" or
      :lti in info.pipe_through
  end

  defp page_area(route, info) do
    cond do
      String.starts_with?(route, "/admin") or
          Enum.any?(
            info.pipe_through,
            &(&1 in [
                :require_authenticated_admin,
                :require_authenticated_system_admin,
                :require_authenticated_account_admin,
                :require_authenticated_content_admin
              ])
          ) ->
        "admin"

      String.starts_with?(route, "/workspaces/instructor") or
        String.contains?(route, "/instructor_dashboard") or
        :require_independent_instructor in info.pipe_through or
          instructor_layout?(info) ->
        "instructor"

      String.starts_with?(route, ["/authoring", "/workspaces/course_author"]) ->
        "authoring"

      String.starts_with?(route, ["/sections", "/workspaces/student"]) ->
        "delivery"

      true ->
        "public"
    end
  end

  defp instructor_layout?(%{phoenix_live_view: {_module, _action, _opts, session}}) do
    case Map.get(session.extra, :layout) do
      {OliWeb.Layouts, layout} ->
        String.starts_with?(Atom.to_string(layout), "instructor_dashboard")

      _ ->
        false
    end
  end

  defp instructor_layout?(_), do: false

  defp traffic_type(assigns) do
    case Accounts.is_system_admin?(Map.get(assigns, :current_author)) do
      true -> "internal"
      false -> "external"
    end
  end
end
