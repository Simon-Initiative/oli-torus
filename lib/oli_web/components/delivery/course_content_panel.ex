defmodule OliWeb.Components.Delivery.CourseContentPanel do
  use Phoenix.Component

  alias OliWeb.Components.Delivery.CourseOutline

  def course_content_panel(assigns) do
    ~H"""
      <div class="container mx-auto mt-3 mb-5">
        <div class="bg-white dark:bg-gray-800 p-8 shadow">
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
