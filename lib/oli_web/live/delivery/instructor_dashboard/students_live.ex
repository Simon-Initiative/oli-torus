defmodule OliWeb.Delivery.InstructorDashboard.StudentsLive do
  use OliWeb, :live_view

  alias OliWeb.Sections.Mount
  alias OliWeb.Components.Delivery.InstructorDashboard
  alias OliWeb.Common.SessionContext

  @impl Phoenix.LiveView
  def mount(_params, %{"section_slug" => section_slug} = session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {_user_type, current_user, section} ->
        section =
          section
          |> Oli.Repo.preload([:base_project, :root_section_resource])

        context = SessionContext.init(session)

        preview_mode = socket.assigns[:live_action] == :preview

        {:ok,
         assign(socket,
           context: context,
           current_user: current_user,
           title: section.title,
           description: section.description,
           section_slug: section_slug,
           preview_mode: preview_mode
         )}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <InstructorDashboard.main_layout {assigns}>
        <InstructorDashboard.students {assigns} />
      </InstructorDashboard.main_layout>
    """
  end
end
