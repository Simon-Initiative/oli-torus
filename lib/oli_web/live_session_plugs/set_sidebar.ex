defmodule OliWeb.LiveSessionPlugs.SetSidebar do
  @moduledoc """
  This live session plug sets the hooks needed to handle the sidebar state (expanded or collapsed)
  by reading the `sidebar_expanded` parameter from the URL and setting it in the socket assigns.
  """

  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]
  import Oli.Utils, only: [string_to_boolean: 1]

  alias Oli.Telemetry.AdminWorkspace
  alias OliWeb.Common.SessionContext

  @platform_student_roles [
    Lti_1p3.Roles.PlatformRoles.get_role(:institution_student),
    Lti_1p3.Roles.PlatformRoles.get_role(:institution_learner)
  ]

  @context_student_roles [
    Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
  ]

  def on_mount(:default, :not_mounted_at_router, _session, socket) do
    # this case will handle the liveview cases rendered directly in the template
    # for example:
    # <%= live_render(@conn, OliWeb.SystemMessageLive.ShowView) %>
    {:cont, socket}
  end

  def on_mount(:default, params, _session, socket) do
    socket =
      socket
      |> assign(
        sidebar_expanded:
          case Map.get(params, "sidebar_expanded") do
            "false" -> false
            _ -> true
          end
      )
      |> assign(disable_sidebar?: user_is_only_a_student?(socket.assigns.ctx))
      |> assign(footer_enabled?: true)

    if connected?(socket) do
      socket =
        attach_hook(socket, :sidebar_hook, :handle_params, fn
          params, uri, socket ->
            previous_assign_uri = Map.get(socket.assigns, :uri)
            sidebar_from_assigns = socket.assigns.sidebar_expanded
            sidebar_from_params = string_to_boolean(params["sidebar_expanded"] || "true")

            socket =
              assign(socket, uri: uri, sidebar_expanded: sidebar_from_params)

            previous_lv_url = socket.private[:connect_params]["_live_referer"]
            current_lv_url = uri

            socket =
              track_admin_nav_transition(
                socket,
                previous_lv_url || previous_assign_uri,
                current_lv_url
              )

            has_sidebar_changed = sidebar_from_assigns != sidebar_from_params
            is_same_workspace = is_same_workspace(previous_lv_url, current_lv_url)

            if is_same_workspace and has_sidebar_changed do
              {:halt, socket}
            else
              {:cont, socket}
            end
        end)

      socket =
        attach_hook(socket, :admin_workspace_breadcrumb, :handle_event, fn
          "admin_workspace_breadcrumb_clicked", %{"target" => target}, socket ->
            sanitized_from = sanitize_route(Map.get(socket.assigns, :uri))
            sanitized_to = sanitize_route(target)

            AdminWorkspace.breadcrumb_use(
              Map.get(socket.assigns, :ctx),
              sanitized_from,
              sanitized_to
            )

            AdminWorkspace.nav_click(
              Map.get(socket.assigns, :ctx),
              sanitized_from,
              sanitized_to,
              :breadcrumb
            )

            {:halt, assign(socket, :__skip_admin_nav__, sanitized_to)}

          _event, _params, socket ->
            {:cont, socket}
        end)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end

  defp is_same_workspace(nil, _current_url) do
    true
  end

  defp is_same_workspace(previous_url, current_url) do
    previous_workspace = extract_workspace(previous_url)
    current_workspace = extract_workspace(current_url)

    previous_workspace == current_workspace
  end

  defp extract_workspace(url) do
    url
    |> URI.parse()
    |> Map.get(:path)
    |> case do
      nil ->
        nil

      path ->
        cond do
          String.starts_with?(path, "/admin") ->
            "admin"

          String.starts_with?(path, "/authoring/communities") ->
            "admin"

          true ->
            path
            |> String.split("/", trim: true)
            |> case do
              ["workspaces", workspace | _rest] -> workspace
              _ -> nil
            end
        end
    end
  end

  defp user_is_only_a_student?(%SessionContext{author: author}) when not is_nil(author), do: false
  defp user_is_only_a_student?(%SessionContext{user: %{can_create_sections: true}}), do: false

  defp user_is_only_a_student?(%SessionContext{user: %{id: user_id}}) do
    user_roles =
      user_id
      |> Oli.Accounts.user_roles()
      |> Enum.map(& &1.uri)
      |> MapSet.new()

    student_roles =
      (@context_student_roles ++ @platform_student_roles)
      |> Enum.map(& &1.uri)
      |> MapSet.new()

    roles_other_than_student = MapSet.difference(user_roles, student_roles)
    MapSet.size(roles_other_than_student) == 0
  end

  defp track_admin_nav_transition(socket, from, to) do
    ctx = Map.get(socket.assigns, :ctx)
    skip_target = Map.get(socket.assigns, :__skip_admin_nav__)

    sanitized_from = sanitize_route(from)
    sanitized_to = sanitize_route(to)

    cond do
      is_nil(ctx) or is_nil(sanitized_to) ->
        socket

      skip_target == sanitized_to ->
        assign(socket, :__skip_admin_nav__, nil)

      extract_workspace(sanitized_to) == "admin" and sanitized_to != sanitized_from ->
        AdminWorkspace.nav_click(
          ctx,
          sanitized_from,
          sanitized_to,
          route_type(sanitized_to)
        )

        assign(socket, :__skip_admin_nav__, nil)

      true ->
        assign(socket, :__skip_admin_nav__, nil)
    end
  end

  defp sanitize_route(nil), do: nil

  defp sanitize_route(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{path: path, query: nil} when not is_nil(path) ->
        path

      %URI{path: path, query: query} when not is_nil(path) and not is_nil(query) ->
        "#{path}?#{query}"

      _ ->
        url
    end
  end

  defp route_type(url) when is_binary(url) do
    case URI.parse(url).path do
      nil ->
        :unknown

      path ->
        if String.starts_with?(path, "/authoring/communities") do
          :community
        else
          :admin
        end
    end
  end

  defp route_type(_), do: :unknown
end
