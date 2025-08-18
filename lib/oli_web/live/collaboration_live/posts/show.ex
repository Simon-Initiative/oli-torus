defmodule OliWeb.CollaborationLive.Posts.Show do
  use OliWeb, :html

  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.Post, as: PostSchema

  alias OliWeb.Common.FormatDateTime
  alias Oli.Resources.Collaboration.Post
  alias OliWeb.Components.Delivery.Buttons

  alias Phoenix.LiveView.JS
  alias OliWeb.Components.Modal

  attr(:post, :map, required: true)
  attr(:is_reply, :boolean, default: false)
  attr(:parent_replies, :list, default: [])
  attr(:parent_post_id, :string, default: nil)
  attr(:index, :string, required: true)
  attr(:user_id, :string, required: true)
  attr(:is_instructor, :boolean, required: true)
  attr(:is_student, :boolean, required: true)
  attr(:is_threaded, :boolean, required: true)
  attr(:is_anonymous, :boolean, required: true)
  attr(:parent_is_archived, :boolean, required: true)
  attr(:is_editing, :boolean, default: false)
  attr(:is_selected, :boolean, default: false)

  def render(assigns) do
    assigns =
      case assigns.is_editing do
        true ->
          assign(assigns, form: to_form(Collaboration.change_post(assigns.post)))

        _ ->
          assign(assigns,
            form:
              to_form(
                Collaboration.change_post(%PostSchema{
                  user_id: assigns.user_id,
                  section_id: assigns.post.section_id,
                  resource_id: assigns.post.resource_id,
                  parent_post_id: assigns.post.id,
                  thread_root_id: assigns.post.thread_root_id || assigns.post.id
                })
              )
          )
      end

    ~H"""
    <div class="flex-col">
      <div class="flex gap-2 mb-3">
        <span class="torus-span post-index">#{@index}</span>

        <div class="border-r border-gray-200 h-10" />

        <div class="flex flex-1 justify-between">
          <div class="flex-col">
            <h6 class="torus-h6 text-sm">{render_name(@post, @user_id)}</h6>
            <small class="torus-small">{render_date(@post.inserted_at)}</small>
          </div>

          <div :if={!@parent_is_archived} class="flex gap-2 items-center">
            <%= if @post.user_id == @user_id do %>
              <button
                class="btn btn-link p-0 text-delivery-primary hover:text-delivery-primary-700 disabled:text-gray-200"
                type="button"
                disabled={@is_editing}
                data-bs-toggle="tooltip"
                title="Edit"
                phx-click="set_editing_post"
                phx-value-post_id={@post.id}
              >
                <i class="fas fa-edit" />
              </button>

              <%= unless @is_instructor do %>
                <span
                  class="d-inline-block"
                  data-bs-toggle="tooltip"
                  title={
                    if has_replies?(@post, @parent_replies, @post.id),
                      do: "Cannot be deleted because it has replies",
                      else: "Delete"
                  }
                >
                  <button
                    class="btn btn-link p-0 text-delivery-primary hover:text-delivery-primary-700 disabled:text-gray-200"
                    type="button"
                    role="display_delete_modal"
                    phx-click={
                      JS.push("display_delete_modal") |> Modal.show_modal("delete_post_modal")
                    }
                    phx-value-id={@post.id}
                    phx-value-index={@index}
                    disabled={has_replies?(@post, @parent_replies, @post.id)}
                  >
                    <i class="fas fa-trash" />
                  </button>
                </span>
              <% end %>
            <% end %>

            <%= if @is_instructor do %>
              <button
                class={"btn btn-link p-0 text-delivery-primary hover:text-delivery-primary-700 disabled:text-gray-200" <>
                  if not @parent_is_archived, do: " not-readonly", else: ""}
                type="button"
                data-bs-toggle="tooltip"
                title={if is_archived?(@post.status), do: "Unarchive", else: "Archive"}
                role="display_archiver_modal"
                phx-click={
                  if is_archived?(@post.status),
                    do:
                      JS.push("display_unarchive_modal") |> Modal.show_modal("unarchive_post_modal"),
                    else: JS.push("display_archive_modal") |> Modal.show_modal("archive_post_modal")
                }
                phx-value-id={@post.id}
                phx-value-index={@index}
              >
                <i class={"fa fa-" <> if is_archived?(@post.status), do: "lock", else: "unlock"} />
              </button>

              <button
                class="btn btn-link p-0 text-delivery-primary hover:text-delivery-primary-700 disabled:text-gray-200"
                type="button"
                data-bs-toggle="tooltip"
                title="Delete"
                role="display_delete_modal"
                phx-click={JS.push("display_delete_modal") |> Modal.show_modal("delete_post_modal")}
                phx-value-id={@post.id}
                phx-value-index={@index}
              >
                <i class="fas fa-trash" />
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <%= if @post.status == :submitted do %>
        <div id={"post_#{@post.id}_actions"} class="flex items-center justify-between mb-3">
          <span class="badge badge-info mr-2 text-xs">Pending approval</span>

          <%= if @is_instructor do %>
            <div class="flex gap-2">
              <button
                class="btn btn-sm btn-success rounded-button"
                data-bs-toggle="tooltip"
                title="Accept"
                role="display_accept_modal"
                phx-click={JS.push("display_accept_modal") |> Modal.show_modal("accept_post_modal")}
                phx-value-id={@post.id}
                phx-value-index={@index}
              >
                <i class="fa fa-check" />
              </button>

              <button
                class="btn btn-sm btn-danger rounded-button"
                data-bs-toggle="tooltip"
                title="Reject"
                role="display_reject_modal"
                phx-click={JS.push("display_reject_modal") |> Modal.show_modal("reject_post_modal")}
                phx-value-id={@post.id}
                phx-value-index={@index}
              >
                <i class="fa fa-times" />
              </button>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @is_threaded and @is_reply and @post.parent_post_id != @parent_post_id do %>
        <small class="mt-2 torus-small reply-info">
          {reply_parent_post_text(assigns, @parent_replies, @index, @post.parent_post_id)}
        </small>
      <% end %>

      <%= if @is_editing do %>
        <.form
          id={"edit_post_form_#{@post.id}"}
          for={@form}
          phx-submit="edit_post"
          class="flex mt-2 flex-col items-end gap-2"
        >
          <div class="hidden">
            <.input type="hidden" field={@form[:user_id]} id={"post_user_id_#{@index}"} />
            <.input type="hidden" field={@form[:section_id]} id={"post_section_id_#{@index}"} />
            <.input type="hidden" field={@form[:resource_id]} id={"post_resource_id_#{@index}"} />
            <.input type="hidden" field={@form[:parent_post_id]} id={"post_parent_post_id_#{@index}"} />
            <.input type="hidden" field={@form[:thread_root_id]} id={"post_thread_root_id_#{@index}"} />
          </div>

          <.inputs_for :let={pc} field={@form[:content]} id={"post_content_#{@index}"}>
            <div class="w-full">
              <.input
                type="textarea"
                field={pc[:message]}
                id={"post_text_area_#{@post.id}"}
                autocomplete="off"
                data-grow="true"
                data-initial-height={44}
                onkeyup="resizeTextArea(this)"
                class="torus-input border-r-0 collab-space__textarea"
              />
            </div>
          </.inputs_for>
          <div class="flex w-full justify-between">
            <div
              :if={@is_threaded and !@is_reply and has_replies?(@post, @parent_replies, @post.id)}
              class="h-10"
            >
              <button
                phx-click="set_selected"
                type="button"
                class="flex items-center text-gray-400 mt-2"
                phx-value-id={@post.id}
              >
                <i class={"fa #{if @is_selected, do: "fa-angle-up", else: "fa-angle-down"} mr-1"} />
                <small>
                  {if @is_selected, do: "Hide replies", else: "Show #{@post.replies_count} replies"}
                </small>
              </button>
            </div>
            <div class="flex gap-2 ml-auto">
              <button
                type="button"
                phx-click="set_editing_post"
                phx-value-post_id={@post.id}
                class="torus-button secondary"
              >
                Cancel
              </button>
              <%= if @is_student and @is_anonymous do %>
                <div class="hidden">
                  <.input type="checkbox" id={"edit_#{@post.id}_checkbox"} field={@form[:anonymous]} />
                </div>
                <Buttons.button_with_options
                  id={"edit_#{@post.id}_save"}
                  type="submit"
                  options={[
                    %{
                      text: "Save as me",
                      on_click:
                        if(@post.anonymous,
                          do:
                            JS.dispatch("click",
                              to: "#edit_#{@post.id}_checkbox"
                            )
                            |> JS.dispatch("click", to: "#edit_#{@post.id}_save_button"),
                          else: JS.dispatch("click", to: "#edit_#{@post.id}_save_button")
                        )
                    },
                    %{
                      text: "Save anonymously",
                      on_click:
                        if(!@post.anonymous,
                          do:
                            JS.dispatch("click",
                              to: "#edit_#{@post.id}_checkbox"
                            )
                            |> JS.dispatch("click", to: "#edit_#{@post.id}_save_button"),
                          else: JS.dispatch("click", to: "#edit_#{@post.id}_save_button")
                        )
                    }
                  ]}
                >
                  Save
                </Buttons.button_with_options>
              <% else %>
                <Buttons.button type="submit">
                  Save
                </Buttons.button>
              <% end %>
            </div>
          </div>
        </.form>
      <% end %>

      <%= if !@is_editing do %>
        <p class="mb-0 text-sm post-content">{@post.content.message}</p>
      <% end %>

      <%= if @is_threaded && !@is_editing do %>
        <.form
          id={"reply_form_#{@post.id}"}
          for={@form}
          phx-submit="create_post"
          class="flex mt-2 flex-col items-end gap-2"
        >
          <div :if={!@parent_is_archived} class="hidden">
            <.input type="hidden" field={@form[:user_id]} id={"post_user_id_#{@index}"} />
            <.input type="hidden" field={@form[:section_id]} id={"post_section_id_#{@index}"} />
            <.input type="hidden" field={@form[:resource_id]} id={"post_resource_id_#{@index}"} />
            <.input type="hidden" field={@form[:parent_post_id]} id={"post_parent_post_id_#{@index}"} />
            <.input type="hidden" field={@form[:thread_root_id]} id={"post_thread_root_id_#{@index}"} />
          </div>
          <.inputs_for
            :let={pc}
            :if={!@parent_is_archived}
            field={@form[:content]}
            id={"post_content_#{@index}"}
          >
            <div class="w-full">
              <.input
                type="textarea"
                field={pc[:message]}
                id={"post_content_message_#{@index}"}
                placeholder="Reply"
                data-grow="true"
                data-initial-height={44}
                onkeyup="resizeTextArea(this)"
                class="torus-input border-r-0 collab-space__textarea reply"
              />
            </div>
          </.inputs_for>
          <div class="flex w-full justify-between">
            <div
              :if={@is_threaded and !@is_reply and has_replies?(@post, @parent_replies, @post.id)}
              class="h-10"
            >
              <button
                phx-click="set_selected"
                type="button"
                class="flex items-center text-gray-400 mt-2"
                phx-value-id={@post.id}
              >
                <i class={"fa #{if @is_selected, do: "fa-angle-up", else: "fa-angle-down"} mr-1"} />
                <small>
                  {if @is_selected, do: "Hide replies", else: "Show #{@post.replies_count} replies"}
                </small>
              </button>
            </div>
            <div :if={!@parent_is_archived} class="collab-space__send-button-with-checkbox ml-auto">
              <%= if @is_student and @is_anonymous do %>
                <div class="hidden">
                  <.input type="checkbox" id={"reply_#{@post.id}_checkbox"} field={@form[:anonymous]} />
                </div>
                <Buttons.button_with_options
                  id={"reply_#{@post.id}_send"}
                  type="submit"
                  options={[
                    %{
                      text: "Reply as me",
                      on_click: JS.dispatch("click", to: "reply_#{@post.id}_send_button")
                    },
                    %{
                      text: "Reply anonymously",
                      on_click:
                        JS.dispatch("click", to: "#reply_#{@post.id}_checkbox")
                        |> JS.dispatch("click", to: "#reply_#{@post.id}_send_button")
                    }
                  ]}
                >
                  Reply
                </Buttons.button_with_options>
              <% else %>
                <Buttons.button type="submit">
                  Reply
                </Buttons.button>
              <% end %>
            </div>
          </div>
        </.form>
      <% end %>
    </div>
    """
  end

  defp render_date(date),
    do: FormatDateTime.format_datetime(date, precision: :relative)

  defp reply_parent_post_text(assigns, replies, thread_index, parent_post_id) do
    thread_index = thread_index |> String.split(".") |> hd()
    {_parent_post, index} = Enum.find(replies, fn {elem, _index} -> elem.id == parent_post_id end)
    assigns = Map.merge(assigns, %{thread_index: thread_index, index: index})

    ~H"""
    {"Replying to ##{@thread_index}.#{@index}:"}
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
