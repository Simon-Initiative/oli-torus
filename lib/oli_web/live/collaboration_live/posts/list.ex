defmodule OliWeb.CollaborationLive.Posts.List do
  use Surface.Component

  alias OliWeb.CollaborationLive.Posts.Show

  prop posts, :list, required: true
  prop collab_space_config, :struct, required: true
  prop user_id, :string, required: true
  prop selected, :string, default: ""
  prop is_instructor, :boolean, required: true

  def render(assigns) do
    ~F"""
    {#for {post, index} <- @posts}
      <div
        id={"accordion_post_#{post.id}"}
        class={"accordion-item post" <>
          if post.status == :archived or @collab_space_config.status == :archived,
            do: " readonly",
            else: ""}
      >
        <div class="accordion-header" id={"heading_#{post.id}"}>
          <Show
            post={post}
            index={index}
            user_id={@user_id}
            is_instructor={@is_instructor}
            is_threaded={@collab_space_config.threaded}
            parent_is_archived={@collab_space_config.status == :archived}
          />
        </div>

        {#if @collab_space_config.threaded}
          <div
            id={"collapse_#{post.id}"}
            class={"collapse w-85 ml-auto" <> if Integer.to_string(post.id) == @selected, do: " show", else: ""}
            aria-labelledby={"heading_#{post.id}"}
            data-parent="#post-accordion"
          >
            <div class="accordion-body">
              {#for {reply, reply_index} <- post.replies}
                <div
                  id={"accordion_reply_#{reply.id}"}
                  class={"reply" <> if reply.status == :archived, do: " readonly", else: ""}
                >
                  <Show
                    post={reply}
                    index={"#{index}.#{reply_index}"}
                    is_reply
                    parent_replies={post.replies}
                    parent_post_id={post.id}
                    user_id={@user_id}
                    is_instructor={@is_instructor}
                    is_threaded={@collab_space_config.threaded}
                    parent_is_archived={@collab_space_config.status == :archived or post.status == :archived}
                  />
                </div>
              {/for}
            </div>
          </div>
        {/if}
      </div>
    {/for}
    """
  end
end
