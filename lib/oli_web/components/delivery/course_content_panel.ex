defmodule OliWeb.Components.Delivery.CourseContentPanel do
  use Phoenix.Component

  import Phoenix.HTML.Link
  import OliWeb.ViewHelpers

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Delivery.CourseOutline

  def course_content_panel(assigns) do
    ~H"""
      <div class="container mx-auto mt-3 mb-5">
        <div class="bg-white dark:bg-gray-800 p-8 shadow">
          <p class="text-secondary"><%= @description %></p>
          <%= if is_section_instructor_or_admin?(@section_slug, @current_user) and not @preview_mode do %>
            <div class="d-flex flex-row my-2">
              <div class="flex-1"></div>
              <div>
                <%= link "Manage Section", to: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, @section_slug), class: "btn btn-warning btn-sm ml-1" %>
              </div>
            </div>
          <% end %>
          <div class="d-flex text-secondary border-b border-secondary mb-2">
            <div class="flex-grow-1">
              <h5>
                Course Overview
              </h5>
            </div>
            <div class="mr-2">
              Pages
            </div>
          </div>
          <ol id="index-container" class="course-outline well" style="list-style: none; padding-left: 0px;">
            <CourseOutline.outline {Map.merge(assigns, %{
              nodes: @hierarchy.children,
              active_page: nil,
            })} />
          </ol>
        </div>
      </div>
    """
  end
end
