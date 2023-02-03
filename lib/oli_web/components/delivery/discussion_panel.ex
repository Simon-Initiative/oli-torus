defmodule OliWeb.Components.Delivery.DiscussionPanel do
  use Phoenix.Component

  def discussion_panel(assigns) do
    ~H"""
      <div class="bg-white dark:bg-gray-800 shadow">
        <div class="p-4">
          Discussion Activity
        </div>
        <div class="p-10 text-center border-t border-gray-100 dark:border-gray-700">
          <div class="mb-2 text-gray-500">
            No new discussion posts
          </div>
          <button class="px-6 py-2.5 text-delivery-primary hover:text-delivery-primary-600 hover:underline active:text-delivery-primary-700">
            <i class="fa-solid fa-plus"></i> Post New Discussion
          </button>
        </div>
      </div>
    """
  end
end
