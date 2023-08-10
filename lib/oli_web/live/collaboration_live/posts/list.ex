defmodule OliWeb.CollaborationLive.Posts.List do
  use Phoenix.Component

  alias OliWeb.CollaborationLive.Posts.Show

  attr(:posts, :list, required: true)
  attr(:collab_space_config, :map, required: true)
  attr(:user_id, :string, required: true)
  attr(:selected, :string, default: "")
  attr(:is_instructor, :boolean, required: true)
  attr(:is_student, :boolean, required: true)
  attr(:editing_post, :string, default: "")

  def render(assigns) do
    ~H"""
    <div id="postsList" phx-hook="TextareaListener">
      <%= for {post, index} <- @posts do %>
        <div
          id={"post_#{post.id}"}
          class={"flex flex-col #{if post.status == :archived or @collab_space_config.status == :archived, do: " readonly", else: ""}"}
        >
          <div class="p-5">
            <Show.render
              post={post}
              index={index}
              user_id={@user_id}
              is_instructor={@is_instructor}
              is_student={@is_student}
              is_threaded={@collab_space_config.threaded}
              is_anonymous={@collab_space_config.anonymous_posting}
              parent_is_archived={@collab_space_config.status == :archived}
              is_editing={@editing_post && @editing_post.id == post.id}
              is_selected={@selected == Integer.to_string(post.id)}
            />
          </div>
          <%= if @collab_space_config.threaded and Integer.to_string(post.id) == @selected do %>
            <div class="bg-gray-100 dark:bg-gray-900" id={"post_#{post.id}_replies"}>
              <div class="flex flex-col gap-4 ml-6">
                <%= for {reply, reply_index} <- post.replies do %>
                  <div
                    id={"post_reply_#{reply.id}"}
                    class={"p-5 bg-white dark:bg-gray-800 show #{if reply_index == 1, do: "mt-4"} #{if reply_index == length(post.replies), do: "mb-4"} #{if reply.status == :archived, do: " readonly"}"}
                    aria-labelledby={"heading_#{post.id}"}
                  >
                    <Show.render
                      post={reply}
                      index={"#{index}.#{reply_index}"}
                      is_reply={true}
                      parent_replies={post.replies}
                      parent_post_id={post.id}
                      user_id={@user_id}
                      is_instructor={@is_instructor}
                      is_student={@is_student}
                      is_threaded={@collab_space_config.threaded}
                      is_anonymous={@collab_space_config.anonymous_posting}
                      parent_is_archived={
                        @collab_space_config.status == :archived or post.status == :archived
                      }
                      is_editing={@editing_post && @editing_post.id == reply.id}
                      is_selected={@selected == Integer.to_string(reply.id)}
                    />
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
          <hr class="border-gray-200 dark:border-gray-700" />
        </div>
      <% end %>
    </div>
    """
  end
end
