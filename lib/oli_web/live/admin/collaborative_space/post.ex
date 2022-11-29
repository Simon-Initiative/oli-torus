defmodule OliWeb.Admin.CollaborativeSpace.Post do
  use Surface.Component

  alias OliWeb.Admin.CollaborativeSpace.Input

  prop post, :struct, required: true
  prop selected, :string
  prop selected_reply, :string
  prop user, :struct
  prop changeset, :changeset, default: nil

  prop create_post, :event, required: true
  prop typing, :event, required: true
  prop stop_typing, :event, required: true
  prop set_selected, :event, required: true
  prop set_selected_reply, :event, required: true

  def render(assigns) do
    ~F"""
    <div class="accordion-item">
      <div class="accordion-header" id={"heading_#{@post.id}"}>
        <div class="border-post-forum border-success p-2 my-4" :on-click="set_selected" phx-value-id={@post.id} data-toggle="collapse" data-target={"#collapse_#{@post.id}"} aria-expanded="true" aria-controls={"collapse_#{@post.id}"}>
          <div class="d-flex align-items-center justify-content-between">
            <div class="my-2">{@post.content.message}</div>
          </div>
          <div class="text-muted small mb-2">XXXX - {@post.inserted_at}</div>
          <div class="d-flex align-items-center justify-content-between">
            <div class="d-flex">
              <div class="badge badge-light mr-1">#{@post.id}</div>
              {#if @post.replies_count > 0}
                <div class="font-weight-light small ml-1"><i class="fa fa-reply-all mr-1"></i>{@post.replies_count}</div>
              {/if}
            </div>
            <div><button type="button" phx-click="display_edit_modal" phx-value-id_post={@post.id} class="btn btn-sm btn-outline-primary">Edit</button></div>
          </div>
        </div>
      </div>
      <div id={"collapse_#{@post.id}"} class={"collapse w-85 ml-auto" <> if Integer.to_string(@post.id) == @selected, do: " show", else: ""} aria-labelledby={"heading_#{@post.id}"} data-parent="#accordion">
        <div class="accordion-body">
          {#for reply <- @post.replies}
            <div class="border-post-forum border-danger mb-3 p-2" :on-click="set_selected_reply" phx-value-id={reply.id} data-toggle="collapse" data-target={"#collapse_reply#{reply.id}"} aria-expanded="true" aria-controls={"collapse_reply#{reply.id}"}>
            {#if reply.parent_post_id != @post.id}
              <span class="badge badge-light">Replied to <strong>XXXX</strong> in <strong>#{reply.parent_post_id}</strong></span>
            {/if}
            <div class="my-2">{reply.content.message}</div>
            <div class="text-muted small mb-2">XXXX - {reply.inserted_at}</div>
            <div class="d-flex align-items-center justify-content-between">
              <div class="d-flex">
                <div class="badge badge-light mr-1">#{reply.id}</div>
                {#if reply.replies_count > 0}
                  <div class="font-weight-light small ml-1"><i class="fa fa-reply-all mr-1"></i>{reply.replies_count}</div>
                {/if}
              </div>
              <div><button type="button" phx-click="display_edit_modal" phx-value-id_post={reply.id} class="btn btn-sm btn-outline-primary">Edit</button></div>
            </div>
            </div>
            <div id={"collapse_reply#{reply.id}"} class={"collapse ml-auto" <> if Integer.to_string(reply.id) == @selected_reply, do: " show", else: ""}>
                <Input id={"input_#{reply.id}"} changeset={@changeset} button_text={"Reply"} parent_id={reply.id} root_id={@post.id} typing="typing" stop_typing="stop_typing" create_post="create_post" />
            </div>
          {/for}
          <hr class="bg-secondary">
          <Input id={"input_#{@post.id}"} changeset={@changeset} button_text={"Reply"} parent_id={@post.id} root_id={@post.id} typing="typing" stop_typing="stop_typing" create_post="create_post" />
        </div>
      </div>
    </div>
    """
  end
end
