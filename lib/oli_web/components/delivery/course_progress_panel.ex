defmodule OliWeb.Components.Delivery.CourseProgressPanel do
  use Phoenix.Component

  import OliWeb.Components.Delivery.Utils

  attr :progress, :integer

  def progress_panel(assigns) do
    ~H"""
      <div class="bg-white dark:bg-gray-800 shadow">
        <div class="p-4">
          Course Progress
        </div>
        <div class="p-4 border-t border-gray-100 dark:border-gray-700">
          <div class="font-semibold">
            Overall Course Progress
          </div>
          <div>
            <.progress_bar percent={@progress} />
          </div>
          <%!-- TODO: UX removed until infrastructure is in place --%>
          <%!-- <div class="text-delivery-primary flex flex-row justify-end">
            <a href="#" class="px-6 py-2.5 text-delivery-primary hover:text-delivery-primary-600 hover:underline active:text-delivery-primary-700">
              View <i class="fa-solid fa-arrow-right ml-1"></i>
            </a>
          </div> --%>
        </div>
        <%!-- TODO: UX removed until infrastructure is in place --%>
        <%!-- <div class="p-4 border-t border-gray-100 dark:border-gray-700">
          <div class="font-semibold">
            Overall Assignment Progress
          </div>
          <div>
            <.progress_bar percent={3} />
          </div>
          <div class="flex flex-row justify-end">
            <a href="#" class="px-6 py-2.5 text-delivery-primary hover:text-delivery-primary-600 hover:underline active:text-delivery-primary-700">
              View All Assignments <i class="fa-solid fa-arrow-right ml-1"></i>
            </a>
          </div>
        </div>
        <div class="p-4 border-t border-gray-100 dark:border-gray-700">
          <div class="text-delivery-primary flex flex-row justify-end">
            <a href="#" class="px-6 py-2.5 text-delivery-primary hover:text-delivery-primary-600 hover:underline active:text-delivery-primary-700">
              View Grades in LMS <i class="fa-solid fa-arrow-right ml-1"></i>
            </a>
          </div>
        </div> --%>
      </div>
    """
  end
end
