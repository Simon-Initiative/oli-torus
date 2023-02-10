defmodule OliWeb.Delivery.InstructorDashboard.ContentLive do
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

        preview_mode = socket.assigns[:live_action] == :preview

        logo_link =
          if preview_mode do
            Routes.content_path(OliWeb.Endpoint, :preview, section_slug)
          else
            Routes.page_delivery_path(OliWeb.Endpoint, :index, section_slug)
          end

        IO.inspect(logo_link, label: "logo_link")

        {:ok,
         assign(socket,
           current_user: current_user,
           title: section.title,
           description: section.description,
           section_slug: section_slug,
           section: section,
           hierarchy: Sections.build_hierarchy(section),
           display_curriculum_item_numbering: section.display_curriculum_item_numbering,
           preview_mode: preview_mode,
           logo_link: logo_link,
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
        <InstructorDashboard.content {assigns} />
      </InstructorDashboard.main_layout>
    """
  end
end
