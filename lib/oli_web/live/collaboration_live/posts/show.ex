defmodule OliWeb.CollaborationLive.Posts.Show do
  use Surface.Component

  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.Post, as: PostSchema

  alias OliWeb.Common.FormatDateTime
  alias Oli.Resources.Collaboration.Post

  alias Surface.Components.Form

  alias Surface.Components.Form.{
    Field,
    TextArea,
    HiddenInput,
    Inputs,
    Checkbox,
    Label
  }

  prop post, :struct, required: true
  prop is_reply, :boolean, default: false
  prop parent_replies, :list, default: []
  prop parent_post_id, :string, default: nil
  prop index, :integer, required: true
  prop user_id, :string, required: true
  prop is_instructor, :boolean, required: true
  prop is_student, :boolean, required: true
  prop is_threaded, :boolean, required: true
  prop parent_is_archived, :boolean, required: true
  prop is_editing, :boolean, default: false
  prop is_selected, :boolean, default: false

  data changeset, :struct

  def render(assigns) do
    assigns =
      case assigns.is_editing do
        true ->
          assign(assigns, changeset: Collaboration.change_post(assigns.post))

        _ ->
          assign(assigns,
            changeset:
              Collaboration.change_post(%PostSchema{
                user_id: assigns.user_id,
                section_id: assigns.post.section_id,
                resource_id: assigns.post.resource_id,
                parent_post_id: assigns.post.id,
                thread_root_id: assigns.post.parent_post_id || assigns.post.id
              })
          )
      end

    ~F"""
    <div class="flex-col">
      <div class="flex gap-2 mb-3">
        <span class="torus-span post-index">#{@index}</span>

        <div class="border-r border-gray-200 h-10" />

        <div class="flex flex-1 justify-between">
          <div class="flex-col">
            <h6 class="torus-h6 text-sm">{render_name(@post, @user_id)}</h6>
            <small class="torus-small">{render_date(@post.inserted_at)}</small>
          </div>

          <div class="flex gap-2 items-center">
            {#if @post.user_id == @user_id}
              <button
                class="btn btn-link p-0 text-delivery-primary hover:text-delivery-primary-700 disabled:text-gray-200"
                type="button"
                disabled={@is_editing}
                data-toggle="tooltip"
                title="Edit"
                :on-click="set_editing_post"
                phx-value-post_id={@post.id}
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
                    class="btn btn-link p-0 text-delivery-primary hover:text-delivery-primary-700 disabled:text-gray-200"
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
                class={"btn btn-link p-0 text-delivery-primary hover:text-delivery-primary-700 disabled:text-gray-200" <>
                  if not @parent_is_archived, do: " not-readonly", else: ""}
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
                class="btn btn-link p-0 text-delivery-primary hover:text-delivery-primary-700 disabled:text-gray-200"
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
          </div>
        </div>
      </div>

      {#if @post.status == :submitted}
        <div id={"post_#{@post.id}_actions"} class="flex items-center justify-between mb-3">
          <span class="badge badge-info mr-2 text-xs">Pending approval</span>

          {#if @is_instructor}
            <div class="flex gap-2">
              <button
                class="btn btn-sm btn-success rounded-button"
                data-toggle="tooltip"
                title="Accept"
                :on-click="display_accept_modal"
                phx-value-id={@post.id}
                phx-value-index={@index}
              >
                <i class="fa fa-check" />
              </button>

              <button
                class="btn btn-sm btn-danger rounded-button"
                data-toggle="tooltip"
                title="Reject"
                :on-click="display_reject_modal"
                phx-value-id={@post.id}
                phx-value-index={@index}
              >
                <i class="fa fa-times" />
              </button>
            </div>
          {/if}
        </div>
      {/if}

      {#if @is_threaded and @is_reply and @post.parent_post_id != @parent_post_id}
        <small class="mt-2 torus-small reply-info">
          {reply_parent_post_text(assigns, @parent_replies, @index, @post.parent_post_id)}
        </small>
      {/if}

      {#if !@is_editing}
        <p class="mb-0 text-sm post-content">{@post.content.message}</p>
      {#elseif @is_editing}
        <Form
          id={"edit_post_form_#{@post.id}"}
          for={@changeset}
          submit="edit_post"
          opts={autocomplete: "off"}
          class="flex mt-2 flex-col items-end gap-2"
        >
          <HiddenInput field={:user_id} />
          <HiddenInput field={:section_id} />
          <HiddenInput field={:resource_id} />

          <HiddenInput field={:parent_post_id} />
          <HiddenInput field={:thread_root_id} />

          <Inputs for={:content}>
            <Field class="w-full" name={:message}>
              <TextArea
                id={"post_text_area_#{@post.id}"}
                opts={
                  "data-grow": "true",
                  "data-initial-height": 44,
                  onkeyup: "resizeTextArea(this)"
                }
                class="torus-input border-r-0 collab-space__textarea"
              />
            </Field>
          </Inputs>
        </Form>
      {/if}

      {#if @is_threaded && !@is_editing}
        <Form
          id={"reply_form_#{@post.id}"}
          for={@changeset}
          submit="create_post"
          opts={autocomplete: "off"}
          class="flex mt-2 flex-col items-end gap-2"
        >
          <HiddenInput field={:user_id} />
          <HiddenInput field={:section_id} />
          <HiddenInput field={:resource_id} />

          <HiddenInput field={:parent_post_id} />
          <HiddenInput field={:thread_root_id} />

          <Inputs for={:content}>
            <Field class="w-full" name={:message}>
              <TextArea
                opts={
                  placeholder: "Reply",
                  "data-grow": "true",
                  "data-initial-height": 44,
                  onkeyup: "resizeTextArea(this)"
                }
                class="torus-input border-r-0 collab-space__textarea reply"
              />
            </Field>
          </Inputs>
          {#if @is_student}
            <Field class={if !@is_editing, do: "collab-space__checkbox"}>
              <Checkbox field={:anonymous} />
              <Label class="text-xs" text="Anonymous"/>
            </Field>
          {/if}
        </Form>
      {/if}

      <div class={"flex w-full justify-between #{if @is_threaded, do: "h-10"}"}>
        {#if @is_threaded and !@is_reply and has_replies?(@post, @parent_replies, @post.id)}
          <button
            :on-click="set_selected"
            type="button"
            class="flex items-center text-gray-400 mt-2"
            phx-value-id={@post.id}
            data-toggle="collapse"
            data-target={"#collapse_#{@post.id}"}
            aria-expanded="true"
            aria-controls={"collapse_#{@post.id}"}
          >
            <i class={"fa #{if @is_selected, do: "fa-angle-up", else: "fa-angle-down"} mr-1"} />
            <small>{if @is_selected, do: "Hide replies", else: "Show #{@post.replies_count} replies"}</small>
          </button>
        {/if}
        <div class="flex gap-2 ml-auto">
          {#if @is_editing}
            <button
              type="button"
              :on-click="set_editing_post"
              phx-value-post_id={@post.id}
              class="torus-button secondary ml-auto"
            >Cancel</button>
            <button form={"edit_post_form_#{@post.id}"} type="submit" class="torus-button primary ml-auto">Save</button>
          {#elseif @is_threaded}
            <button
              form={"reply_form_#{@post.id}"}
              type="submit"
              class="torus-button primary ml-auto collab-space__send-button"
            >Send</button>
          {/if}
        </div>
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
    Replying to #{thread_index}.{index}:
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

  defp render_name(%PostSchema{anonymous: true, user_id: post_user_id} = post, user_id)
       when post_user_id == user_id,
       do: "#{post.user.name} (Me as Anonymous user)"

  defp render_name(%PostSchema{anonymous: false, user_id: post_user_id} = post, user_id)
       when post_user_id == user_id,
       do: "#{post.user.name} (Me)"

  defp render_name(%PostSchema{anonymous: true}, _user_id), do: "Anonymous user"
  defp render_name(post, _user_id), do: post.user.name
end
