defmodule OliWeb.Delivery.InstructorDashboard.InitialAssigns do
  @moduledoc """
  Ensure common assigns are applied to all InstructorDashboard LiveViews attaching this hook.
  """
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.SessionContext
  alias OliWeb.Router.Helpers, as: Routes

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, %{"section_slug" => section_slug} = session, socket) do
    case Mount.for(section_slug, session) do
      {:error, error} ->
        {:halt, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, error))}

      {_user_type, current_user, section} ->
        section =
          section
          |> Oli.Repo.preload([:base_project, :root_section_resource])

        context = SessionContext.init(session)

        preview_mode = socket.assigns[:live_action] == :preview

        {:cont,
         assign(socket,
           context: context,
           current_user: current_user,
           title: section.title,
           description: section.description,
           section_slug: section_slug,
           preview_mode: preview_mode,
           section: section
         )}
    end
  end
end
