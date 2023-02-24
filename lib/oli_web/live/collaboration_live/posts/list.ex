defmodule OliWeb.CollaborationLive.Posts.List do
  use Surface.Component

  alias OliWeb.CollaborationLive.Posts.Show

  prop posts, :list, required: true
  prop collab_space_config, :struct, required: true
  prop user_id, :string, required: true
  prop selected, :string, default: ""
  prop is_instructor, :boolean, required: true
  prop editing_post, :string, default: ""

  def render(assigns) do
    ~F"""
    <div id="postsList" phx-hook="TextareaListener">
      {#for {post, index} <- @posts}
        <div class="flex flex-col">
          <div class="p-5">
            <Show
              post={post}
              index={index}
              user_id={@user_id}
              is_instructor={@is_instructor}
              is_threaded={@collab_space_config.threaded}
              parent_is_archived={@collab_space_config.status == :archived}
              is_editing={@editing_post && @editing_post.id == post.id}
              is_selected={@selected == Integer.to_string(post.id)}
            />
          </div>
          {#if @collab_space_config.threaded and Integer.to_string(post.id) == @selected}
            <div class="bg-gray-100">
              <div class="flex flex-col gap-4 ml-6">
                {#for {reply, reply_index} <- post.replies}
                  <div
                    id={"collapse_#{post.id}"}
                    class={"collapse p-5 bg-white show #{if reply_index == 1, do: "mt-4"} #{if reply_index == length(post.replies), do: "mb-4"}"}
                    aria-labelledby={"heading_#{post.id}"}
                    data-parent="#post-accordion"
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
                      is_editing={@editing_post && @editing_post.id == reply.id}
                      is_selected={@selected == Integer.to_string(reply.id)}
                    />
                  </div>
                {/for}
              </div>
            </div>
          {/if}
          <hr class="border-gray-200">
        </div>
      {/for}
    </div>
    """
  end
end
