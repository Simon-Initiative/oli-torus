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

    section = Oli.Repo.get(Oli.Delivery.Sections.Section, section_id)

    {:ok,
     assign(socket,
       last_posts_user: last_posts_user,
       last_posts_section: last_posts_section,
       section_slug: section.slug
     )}
  end

  def render(assigns) do
    ~H"""
      <div class="flex flex-col justify-start mt-4 px-7 sm:px-0">
        <h6 class="text-xl font-normal leading-8 tracking-wide">Discussion Board</h6>
      </div>

      <DiscussionPost.render last_posts={@last_posts_user} title="Your Latest Discussion Activity" section_slug={@section_slug}/>
      <DiscussionPost.render last_posts={@last_posts_section} title="All Discussion Activity" section_slug={@section_slug}/>
    """
  end
end
