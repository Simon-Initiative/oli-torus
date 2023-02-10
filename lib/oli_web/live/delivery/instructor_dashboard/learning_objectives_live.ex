defmodule OliWeb.Delivery.InstructorDashboard.LearningObjectivesLive do
  use OliWeb, :live_view

  alias OliWeb.Router.Helpers, as: Routes
  alias alias Oli.Delivery.Sections
  alias OliWeb.Sections.Mount
  alias OliWeb.Components.Delivery.InstructorDashboard

  @impl Phoenix.LiveView
  def mount(_params, %{"section_slug" => section_slug} = session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {_user_type, current_user, section} ->
        section =
          section
          |> Oli.Repo.preload([:base_project, :root_section_resource])

        {:ok,
         assign(socket,
           current_user: current_user,
           title: section.title,
           description: section.description,
           section_slug: section_slug,
           hierarchy: Sections.build_hierarchy(section),
           display_curriculum_item_numbering: section.display_curriculum_item_numbering,
           preview_mode: true,
           page_link_url:
             &Routes.page_delivery_path(OliWeb.Endpoint, :page_preview, section_slug, &1),
           container_link_url:
             &Routes.page_delivery_path(OliWeb.Endpoint, :container_preview, section_slug, &1)
         )}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <InstructorDashboard.main_layout {assigns}>
        <InstructorDashboard.learning_objectives {assigns} />
      </InstructorDashboard.main_layout>
    """
  end
end
