defmodule OliWeb.CollaborationLive.ShowPost do
  use Surface.Component

  prop post, :struct, required: true
  prop index, :integer, required: true
  prop user, :struct
  prop selected, :string, default: ""
  prop is_threaded, :boolean, required: true

  def render(assigns) do
    ~F"""
      <div class={"accordion-item" <> if @post.status == :archived, do: " readonly", else: ""}>
        <div class="accordion-header" id={"heading_#{@post.id}"}>
          <div class="border-post-forum border-success p-2 my-4">
            {#if @post.status == :submitted}
              <span class={"badge" <> if @post.status == :submitted, do: " badge-success"}>{@post.status}</span>
            {/if}

            <div class="my-2">{@post.content.message}</div>

            <div class="text-muted small mb-2">{@post.user.name} - {@post.inserted_at}</div>

            <div class="badge badge-light mr-1">#{@index}</div>

            {#if @post.replies_count > 0}
              <div class="font-weight-light small ml-1"><i class="fa fa-reply-all mr-1"></i>{@post.replies_count}</div>
            {/if}

            {#if @post.user_id == @user.id}
              <button class="btn btn-link" type="button" :on-click="display_edit_modal" phx-value-id={@post.id}><i class="fas fa-edit"></i></button>
            {/if}

            {#if @is_threaded}
              <button class="btn btn-link" type="button" :on-click="display_reply_to_post_modal" phx-value-parent_id={@post.id}><i class="fas fa-reply"></i></button>
              {#if @post.replies_count > 0}
                <button class="btn btn-link not-readonly" :on-click="set_selected" phx-value-id={@post.id} data-toggle="collapse" data-target={"#collapse_#{@post.id}"} aria-expanded="true" aria-controls={"collapse_#{@post.id}"}><i class="fa fa-angle-down mr-1"></i></button>
              {/if}
            {/if}
          </div>
        </div>
        {#if @is_threaded}
          <div id={"collapse_#{@post.id}"} class={"collapse w-85 ml-auto" <> if Integer.to_string(@post.id) == @selected, do: " show", else: ""} aria-labelledby={"heading_#{@post.id}"} data-parent="#post-accordion">
            <div class="accordion-body">

              {#for {reply, reply_index} <- @post.replies}
                <div class={"border-post-forum border-danger mb-3 p-2" <> if reply.status == :archived, do: " readonly", else: ""}>

                  {#if reply.status == :submitted}
                  <span class={"badge" <> if reply.status == :submitted, do: " badge-success"}>{reply.status}</span>
                  {/if}

                  {#if reply.parent_post_id != @post.id}
                    <span class="badge badge-light">{reply_parent_post_text(assigns, @post.replies, @index, reply.parent_post_id)}</span>
                  {/if}

                  <div class="my-2">{reply.content.message}</div>
                  <div class="text-muted small mb-2">{reply.user.name} - {reply.inserted_at}</div>

                  <div class="badge badge-light mr-1">#{@index}.{reply_index}</div>

                  {#if reply.replies_count > 0}
                    <div class="font-weight-light small ml-1"><i class="fa fa-reply-all mr-1"></i>{reply.replies_count}</div>
                  {/if}

                  {#if reply.user_id == @user.id}
                    <button class="btn btn-link" type="button" :on-click="display_edit_modal" phx-value-id={reply.id}><i class="fas fa-edit"></i></button>
                  {/if}
                  <button class="btn btn-link" type="button" :on-click="display_reply_to_reply_modal" phx-value-parent_id={reply.id} phx-value-root_id={@post.id}><i class="fas fa-reply"></i></button>
                </div>
              {/for}
            </div>
          </div>
        {/if}
      </div>
    """
  end

  defp reply_parent_post_text(assigns, replies, thread_index, parent_post_id) do
    {parent_post, index} = Enum.find(replies, fn {elem, _index} -> elem.id == parent_post_id end)

    ~F"""
      Replied to {parent_post.user.name} in #{thread_index}.{index}
    """
  end
end
