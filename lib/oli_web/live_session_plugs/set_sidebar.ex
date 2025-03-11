defmodule OliWeb.LiveSessionPlugs.SetSidebar do
  @moduledoc """
  This live session plug sets the hooks needed to handle the sidebar state (expanded or collapsed)
  by reading the `sidebar_expanded` parameter from the URL and setting it in the socket assigns.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]
  import Oli.Utils, only: [string_to_boolean: 1]

  alias OliWeb.Common.SessionContext

  @platform_student_roles [
    Lti_1p3.Tool.PlatformRoles.get_role(:institution_student),
    Lti_1p3.Tool.PlatformRoles.get_role(:institution_learner)
  ]

  @context_student_roles [
    Lti_1p3.Tool.ContextRoles.get_role(:context_learner)
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
            sidebar_from_assigns = socket.assigns.sidebar_expanded
            sidebar_from_params = string_to_boolean(params["sidebar_expanded"] || "true")

            socket = assign(socket, uri: uri, sidebar_expanded: sidebar_from_params)

            previous_lv_url = socket.private[:connect_params]["_live_referer"]
            current_lv_url = uri

            has_sidebar_changed = sidebar_from_assigns != sidebar_from_params
            is_same_workspace = is_same_workspace(previous_lv_url, current_lv_url)

            if is_same_workspace and has_sidebar_changed do
              {:halt, socket}
            else
              {:cont, socket}
            end
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
    URI.parse(url)
    |> Map.get(:path)
    |> String.split("/", trim: true)
    |> case do
      ["workspaces", workspace | _rest] ->
        workspace

      _ ->
        nil
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
end
