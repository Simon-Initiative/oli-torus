defmodule OliWeb.CollaborationLive.ShowPost do
  use Surface.Component

  alias OliWeb.Common.FormatDateTime

  prop post, :struct, required: true
  prop index, :integer, required: true
  prop user, :struct
  prop selected, :string, default: ""
  prop is_threaded, :boolean, required: true
  prop is_instructor, :boolean, required: true

  def render(assigns) do
    ~F"""
      <div id={"accordion_post_#{@post.id}"} class={"accordion-item" <> if @post.status == :archived and not @is_instructor, do: " readonly", else: ""}>
        <div class="accordion-header" id={"heading_#{@post.id}"}>
          <div class="card border-post my-3">
            <div class="card-header d-flex justify-content-between align-items-center p-0">
              <div class="d-flex align-items-center">
                <div class="h3 mb-0 border-index">#{@index}</div>
                <div class="p-2 text-username">{@post.user.name}</div>
              </div>

              <div class="small text-light font-italic mr-3">{FormatDateTime.format_datetime(@post.inserted_at, precision: :relative)}</div>
            </div>

            <div class="card-body pb-2">
              {#if @post.status == :submitted}
                <div class="d-flex justify-content-end"><div class="badge badge-info mb-2">Pending approval</div></div>
              {/if}

              <div><p class="my-1">{@post.content.message}</p></div>
              <hr class="bg-light"/>

              <div class="d-flex justify-content-between align-items-center">
                <div>
                  {#if @post.user_id == @user.id}
                    <button class="btn btn-link" type="button" data-toggle="tooltip" title="Edit" :on-click="display_edit_modal" phx-value-id={@post.id}><i class="fas fa-edit"></i></button>

                    <span class="d-inline-block" tabindex="0" data-toggle="tooltip" title={if @post.replies_count > 0, do: "Cannot be deleted because it has replies", else: "Delete"}>
                      <button class="btn btn-link" type="button" :on-click="display_delete_modal" phx-value-id={@post.id} phx-value-index={@index} disabled={if @post.replies_count > 0, do: true}><i class="fas fa-trash"></i></button>
                    </span>
                  {/if}
                  {#if @is_instructor}
                    <button class="btn btn-link" type="button" data-toggle="tooltip" title={if is_archived?(@post.status), do: "Archive", else: "Unarchive"} :on-click="display_archive_modal" phx-value-id={@post.id} phx-value-index={@index} phx-value-status={@post.status}><i class={"fa fa-" <> if is_archived?(@post.status), do: "lock", else: "unlock"}></i></button>
                  {/if}
                </div>

                <div>
                  {#if @is_threaded}
                    <button class="btn btn-link" type="button" data-toggle="tooltip" title="Reply" :on-click="display_reply_to_post_modal" phx-value-parent_id={@post.id} phx-value-index={"##{@index}"}><i class="fas fa-reply"></i></button>

                    {#if @post.replies_count > 0}
                      <button class="btn btn-link text-decoration-none not-readonly" :on-click="set_selected" phx-value-id={@post.id} data-toggle="collapse" data-target={"#collapse_#{@post.id}"} aria-expanded="true" aria-controls={"collapse_#{@post.id}"}>
                        <div class="d-flex align-items-center">
                          <div class="d-flex flex-column mr-2">
                            <div class="small">{@post.replies_count}</div>
                            <div class="small">replies</div>
                          </div>
                          <div><i class="fa fa-angle-down mr-1"></i></div>
                        </div>
                      </button>
                    {/if}
                  {/if}
                </div>
              </div>
            </div>
          </div>
        </div>

        {#if @is_threaded}
          <div id={"collapse_#{@post.id}"} class={"collapse w-85 ml-auto" <> if Integer.to_string(@post.id) == @selected, do: " show", else: ""} aria-labelledby={"heading_#{@post.id}"} data-parent="#post-accordion">
            <div class="accordion-body">
              {#for {reply, reply_index} <- @post.replies}
                <div id={"accordion_reply_#{reply.id}"} class={"card border-reply mb-3 p-2" <> if reply.status == :archived and not @is_instructor, do: " readonly", else: ""}>
                  <div class="card-header d-flex justify-content-between align-items-center p-0">
                    <div class="d-flex align-items-center">
                      <div class="h4 mb-0 border-index">#{@index}.{reply_index}</div>
                      <div class="p-2 text-username">{reply.user.name}</div>
                    </div>

                    <div class="small text-light font-italic mr-3">{FormatDateTime.format_datetime(reply.inserted_at, precision: :relative)}</div>
                  </div>

                  <div class="card-body pb-2">
                    {#if reply.status == :submitted}
                      <div class="d-flex justify-content-end"><div class="badge badge-info mb-2">Pending approval</div></div>
                    {/if}

                    <div><p class="my-1">{reply.content.message}</p></div>
                    <hr class="bg-light"/>

                    <div class="d-flex justify-content-between align-items-center">
                      <div>
                        {#if reply.user_id == @user.id}
                          <button class="btn btn-link" type="button" data-toggle="tooltip" title="Edit" :on-click="display_edit_modal" phx-value-id={reply.id}><i class="fas fa-edit"></i></button>

                          <span class="d-inline-block" tabindex="0" data-toggle="tooltip" title={if has_replies?(@post.replies, reply.id), do: "Cannot be deleted because it has replies", else: "Delete"}>
                            <button class="btn btn-link" type="button" :on-click="display_delete_modal" phx-value-id={reply.id} phx-value-index={"#{@index}.#{reply_index}"} disabled={has_replies?(@post.replies, reply.id)}><i class="fas fa-trash"></i></button>
                          </span>
                        {/if}
                        {#if @is_instructor}
                            <button class="btn btn-link" type="button" data-toggle="tooltip" title={if is_archived?(reply.status), do: "Archive", else: "Unarchived"} :on-click="display_archive_modal" phx-value-id={reply.id} phx-value-index={"#{@index}.#{reply_index}"} phx-value-status={reply.status}><i class={"fa fa-" <> if is_archived?(reply.status), do: "lock", else: "unlock"}></i></button>
                        {/if}
                      </div>

                      <div>
                        {#if reply.parent_post_id != @post.id}
                          <span class="small text-light font-italic">{reply_parent_post_text(assigns, @post.replies, @index, reply.parent_post_id)}</span>
                        {/if}

                        <button class="btn btn-link" type="button" data-toggle="tooltip" title="Reply" :on-click="display_reply_to_reply_modal" phx-value-parent_id={reply.id} phx-value-root_id={@post.id} phx-value-index={"##{@index}.#{reply_index}"}><i class="fas fa-reply"></i></button>
                      </div>
                    </div>
                  </div>
                </div>
              {/for}
            </div>
          </div>
        {/if}
      </div>
    """
  end

  defp reply_parent_post_text(assigns, replies, thread_index, parent_post_id) do
    {_parent_post, index} = Enum.find(replies, fn {elem, _index} -> elem.id == parent_post_id end)

    ~F"""
      Replied #{thread_index}.{index}
    """
  end

  defp has_replies?(replies, reply_id) do
    some_child =
      replies
      |> Enum.unzip()
      |> elem(0)
      |> Enum.find(&(&1.parent_post_id == reply_id))

    not is_nil(some_child)
  end

  defp is_archived?(:archived), do: true
  defp is_archived?(_), do: false
end
