defmodule OliWeb.Delivery.InstructorDashboard.InitialAssigns do
  @moduledoc """
  Ensure common assigns are applied to all InstructorDashboard LiveViews attaching this hook.
  """
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.SessionContext
  alias OliWeb.Router.Helpers, as: Routes

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, :not_mounted_at_router, _session, socket) do
    {:cont, socket}
  end

  def on_mount(:default, %{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, error} ->
        {:halt, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, error))}

      {_user_type, current_user, section} ->
        section =
          section
          |> Oli.Repo.preload([:base_project, :root_section_resource])

        {:cont,
         assign(socket,
           context: SessionContext.init(session),
           current_user: current_user,
           title: section.title,
           description: section.description,
           section_slug: section_slug,
           preview_mode: socket.assigns[:live_action] == :preview,
           section: section
         )}
    end
  end
end
