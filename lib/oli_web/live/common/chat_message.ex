defmodule OliWeb.Common.ChatMessage do
  use Surface.Component

  prop messages, :list, required: true
  prop enabled_comment, :event, required: true
  prop is_enabled_comment, :boolean, default: false

  def render(assigns) do
    ~F"""
     {#for message <- @messages}
        <div class="container">
          <div class="">
            <div>{message.text}</div>
            <div class="d-flex justify-content-between align-items-center">
              <div class="text-muted">{message.author.name}</div>
              <div><button type="button" class="btn btn-sm btn-primary" :on-click={@enabled_comment}>+</button></div>
            </div>
          </div>
          <!-- <div class="collapse w-75 ml-auto" id={"collapse#{message.id}"}>
            <div class="card card-body">
              <form for={:message} :on-submit="add_comment" :on-change="typing" autocomplete="off">
                <div class="form-group">
                  <input type="text" name={:message} value="" :on-blur="stop_typing" class="form-control" placeholder="Write reply">
                </div>
                <div class="d-flex justify-content-end"><button type="submit" class="btn btn-sm btn-primary">Post reply</button></div>
              </form>
            </div>
          </div> -->
          {#for reply <- message.replies}
              <div>{reply.text}</div>
          {/for}
        </div>
      {/for}
    """
  end
end
