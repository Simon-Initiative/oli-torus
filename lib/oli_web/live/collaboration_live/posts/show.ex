defmodule OliWeb.CollaborationLive.Posts.Show do
  use Surface.Component

  alias OliWeb.Common.FormatDateTime
  alias Oli.Resources.Collaboration.Post

  prop post, :struct, required: true
  prop is_reply, :boolean, default: false
  prop parent_replies, :list, default: []
  prop parent_post_id, :string, default: nil
  prop index, :integer, required: true
  prop user_id, :string, required: true
  prop is_instructor, :boolean, required: true
  prop is_threaded, :boolean, required: true
  prop parent_is_archived, :boolean, required: true

  def render(assigns) do
    ~F"""
    <div class="card post-border my-3">
      <div class="card-header d-flex justify-content-between align-items-center p-0">
        <div class="d-flex align-items-center">
          <div class="mb-0 post-index">#{@index}</div>
          <h6 class="p-2 mb-0 font-weight-light">{@post.user.name}</h6>
        </div>

        <small class="text-light font-italic mr-3">{render_date(@post.inserted_at)}</small>
      </div>

      <div class="card-body pb-2">
        {#if @post.status == :submitted}
          <div class="d-flex justify-content-end align-items-center">
            <span class="badge badge-info mr-2">Pending approval</span>

            {#if @is_instructor}
              <button
                class="btn btn-sm btn-success rounded-button mr-1"
                data-toggle="tooltip"
                title="Accept"
                :on-click="display_accept_modal"
                phx-value-id={@post.id}
                phx-value-index={@index}
              >
                <i class="fa fa-check" />
              </button>

              <button
                class="btn btn-sm btn-danger rounded-button ml-1"
                data-toggle="tooltip"
                title="Reject"
                :on-click="display_reject_modal"
                phx-value-id={@post.id}
                phx-value-index={@index}
              >
                <i class="fa fa-times" />
              </button>
            {/if}
          </div>
        {/if}

        <p class="my-1">{@post.content.message}</p>
        <hr class="bg-light">

        {#if @post.user_id == @user_id}
          <button
            class="btn btn-link"
            type="button"
            data-toggle="tooltip"
            title="Edit"
            :on-click="display_edit_modal"
            phx-value-id={@post.id}
          >
            <i class="fas fa-edit" />
          </button>

          {#unless @is_instructor}
            <span
              class="d-inline-block"
              data-toggle="tooltip"
              title={if has_replies?(@post, @parent_replies, @post.id),
                do: "Cannot be deleted because it has replies",
                else: "Delete"}
            >
              <button
                class="btn btn-link"
                type="button"
                :on-click="display_delete_modal"
                phx-value-id={@post.id}
                phx-value-index={@index}
                disabled={has_replies?(@post, @parent_replies, @post.id)}
              >
                <i class="fas fa-trash" />
              </button>
            </span>
          {/unless}
        {/if}

        {#if @is_instructor}
          <button
            class={"btn btn-link" <> if not @parent_is_archived, do: " not-readonly", else: ""}
            type="button"
            data-toggle="tooltip"
            title={if is_archived?(@post.status), do: "Unarchive", else: "Archive"}
            :on-click={if is_archived?(@post.status), do: "display_unarchive_modal", else: "display_archive_modal"}
            phx-value-id={@post.id}
            phx-value-index={@index}
          >
            <i class={"fa fa-" <> if is_archived?(@post.status), do: "lock", else: "unlock"} />
          </button>

          <button
            class="btn btn-link"
            type="button"
            data-toggle="tooltip"
            title="Delete"
            :on-click="display_delete_modal"
            phx-value-id={@post.id}
            phx-value-index={@index}
          >
            <i class="fas fa-trash" />
          </button>
        {/if}

        {#if @is_threaded}
          <div class="float-right">
            {#if @is_reply}
              {#if @post.parent_post_id != @parent_post_id}
                <small class="text-light font-italic">
                  {reply_parent_post_text(assigns, @parent_replies, @index, @post.parent_post_id)}
                </small>
              {/if}

              <button
                class="btn btn-link"
                type="button"
                data-toggle="tooltip"
                title="Reply"
                :on-click="display_reply_to_reply_modal"
                phx-value-parent_id={@post.id}
                phx-value-root_id={@parent_post_id}
                phx-value-index={"##{@index}"}
              >
                <i class="fas fa-reply" />
              </button>
            {#else}
              <button
                class="btn btn-link"
                type="button"
                data-toggle="tooltip"
                title="Reply"
                :on-click="display_reply_to_post_modal"
                phx-value-parent_id={@post.id}
                phx-value-index={"##{@index}"}
              >
                <i class="fas fa-reply" />
              </button>

              {#if has_replies?(@post, @parent_replies, @post.id)}
                <button
                  class="btn btn-link text-decoration-none not-readonly"
                  :on-click="set_selected"
                  phx-value-id={@post.id}
                  data-toggle="collapse"
                  data-target={"#collapse_#{@post.id}"}
                  aria-expanded="true"
                  aria-controls={"collapse_#{@post.id}"}
                >
                  <div class="d-flex align-items-center">
                    <div class="d-flex flex-column mr-2">
                      <small>{@post.replies_count}</small>
                      <small>replies</small>
                    </div>

                    <i class="fa fa-angle-down mr-1" />
                  </div>
                </button>
              {/if}
            {/if}
          </div>
        {/if}
      </div>
    </div>
    """
  end

  defp render_date(date),
    do: FormatDateTime.format_datetime(date, precision: :relative)

  defp reply_parent_post_text(assigns, replies, thread_index, parent_post_id) do
    thread_index = thread_index |> String.split(".") |> hd()
    {_parent_post, index} = Enum.find(replies, fn {elem, _index} -> elem.id == parent_post_id end)

    ~F"""
    Replied #{thread_index}.{index}
    """
  end

  defp has_replies?(%Post{replies_count: replies_count}, _, _)
       when is_number(replies_count) and replies_count > 0,
       do: true

  defp has_replies?(%Post{replies_count: 0}, [], _), do: false

  defp has_replies?(_, parent_replies, reply_id) do
    some_child =
      parent_replies
      |> Enum.unzip()
      |> elem(0)
      |> Enum.find(&(&1.parent_post_id == reply_id))

    not is_nil(some_child)
  end

  defp is_archived?(:archived), do: true
  defp is_archived?(_), do: false
end
