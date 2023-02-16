defmodule OliWeb.Components.Delivery.DiscussionBoard do
  use Phoenix.LiveView

  alias OliWeb.Components.Delivery.DiscussionPost
  alias Oli.Resources.Collaboration

  @posts_limit 5

  def mount(
        _params,
        %{
          "section_id" => section_id,
          "current_user_id" => current_user_id
        },
        socket
      ) do
    last_posts_user = Collaboration.list_lasts_posts_for_user(current_user_id, section_id, @posts_limit)
    last_posts_section = Collaboration.list_lasts_posts_for_section(current_user_id, section_id, @posts_limit)

    {:ok,
     assign(socket,
       last_posts_user: last_posts_user,
       last_posts_section: last_posts_section
     )}
  end

  def render(assigns) do
    ~H"""
      <div class="flex flex-col md:flex-row justify-between items-center mt-4 sm:mt-16">
        <h6 class="text-xl font-normal leading-8 tracking-wide">Discussion Board</h6>
        <div class="inline-flex">
          <button class="btn text-sm font-normal leading-5 py-2 px-6 text-white hover:text-white inline-flex ml-2 bg-delivery-primary hover:bg-delivery-primary-600 active:bg-delivery-primary-700">+ Create Study Group</button>
          <button class="btn text-sm font-normal leading-5 py-2 px-6 text-white hover:text-white inline-flex ml-2 bg-delivery-primary hover:bg-delivery-primary-600 active:bg-delivery-primary-700">+ New Discussion</button>
        </div>
      </div>

      <DiscussionPost.render last_posts={@last_posts_user} title="Your Latest Discussion Activity"/>
      <DiscussionPost.render last_posts={@last_posts_section} title="All Discussion Activity"/>
    """
  end
end
