defmodule Oli.LiveSessionPlugs.SetProject do
  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, %{"project_id" => project_id}, _session, socket) do
    socket = assign(socket, project: Oli.Authoring.Course.get_project_by_slug(project_id))

    {:cont, socket}
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end
end
