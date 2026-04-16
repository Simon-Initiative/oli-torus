defmodule OliWeb.LiveSessionPlugs.SetProjectOrSection do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections
  alias OliWeb.LiveSessionPlugs.SetProject
  alias OliWeb.LiveSessionPlugs.SetSection

  def on_mount(:default, %{"project_id" => _project_id} = params, session, socket) do
    case SetProject.on_mount(:default, params, session, socket) do
      {:cont, socket} -> {:cont, maybe_load_template_updates_badge(socket)}
      other -> other
    end
  end

  def on_mount(:default, %{"section_slug" => _section_slug} = params, session, socket) do
    SetSection.on_mount(:default, params, session, socket)
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end

  defp maybe_load_template_updates_badge(%{assigns: %{project: %Project{} = project}} = socket) do
    notification_badges = Map.get(socket.assigns, :notification_badges, %{})

    case Sections.count_available_blueprint_updates(project) do
      count when count > 0 ->
        assign(socket,
          notification_badges: Map.put(notification_badges, :template_updates, count)
        )

      _ ->
        assign(socket, notification_badges: notification_badges)
    end
  end

  defp maybe_load_template_updates_badge(socket), do: socket
end
