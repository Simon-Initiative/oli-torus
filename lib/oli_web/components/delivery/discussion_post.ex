defmodule OliWeb.Components.Delivery.DiscussionPost do
  use Phoenix.Component

  import OliWeb.Common.FormatDateTime

  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-800 shadow mt-7 py-6 px-7">
      <span class="font-normal text-base leading-5 tracking-wide">{@title}</span>
    </div>
    <div class="flex flex-col gap-y-0.5 mt-0.5">
      <%= if length(@last_posts) > 0 do %>
        <%= for post <- @last_posts do %>
          <div class="flex flex-col bg-white dark:bg-gray-800 shadow py-4 px-7 gap-y-3">
            <div class="flex flex-row justify-between items-center">
              <a
                class="text-delivery-primary hover:text-delivery-primary"
                href={Routes.page_delivery_path(OliWeb.Endpoint, :page, @section_slug, post.slug)}
              >
                <h6 class="font-normal text-sm leading-5 text-gray-500">{post.title}</h6>
              </a>
              <h6 class="font-medium text-sm leading-5">
                {date(post.updated_at, precision: :relative)}
              </h6>
            </div>
            <h6 class="font-bold text-sm leading-5 tracking-wide">{post.user_name}</h6>
            <p class="mb-0 font-normal text-sm leading-5 tracking-wide">
              {post.content.message}
            </p>
          </div>
        <% end %>
      <% else %>
        <div class="bg-white dark:bg-gray-800 px-7 py-4">
          <h6>There are no posts to show</h6>
        </div>
      <% end %>
    </div>
    """
  end
end
