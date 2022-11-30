defmodule OliWeb.CollaborationLive.CollabSpaceView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias OliWeb.Presence
  alias Phoenix.PubSub
  alias Oli.Accounts
  alias Oli.Delivery.Sections
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.Post

  alias OliWeb.CollaborationLive.{
    Post,
    Input,
    EditModal
  }

  data selected, :string, default: ""
  data selected_reply, :string, default: ""
  data users, :list
  data posts, :list
  data modal, :any, default: nil
  data changeset, :changeset, default: nil
  data collab_space_config, :any

  defp get_posts(filter) do
    all_posts = Collaboration.search_posts(filter)

    Enum.reduce(all_posts, [], fn post, acc ->
      if is_nil(post.thread_root_id) do
        replies = Enum.filter(all_posts, fn child -> child.thread_root_id == post.id end)
        [Map.put(post, :replies, replies)] ++ acc
      else
        acc
      end
    end)
  end

  def mount(
        _,
        %{
          "collab_space_config" => collab_space_config,
          "section_slug" => section_slug,
          "page_slug" => page_slug,
          "current_user_id" => current_user_id
        } = _session,
        socket
      ) do
    topic = "cs_#{section_slug}_#{page_slug}"
    PubSub.subscribe(Oli.PubSub, topic)

    user = Accounts.get_user_by(%{id: current_user_id})
    section = Sections.get_section_by_slug(section_slug)
    page = Resources.get_resource_from_slug(page_slug)
    posts = get_posts(%{status: :approved})

    Presence.track_presence(
      self(),
      topic,
      current_user_id,
      default_user_presence_payload(user)
    )

    {:ok,
     assign(socket,
       topic: topic,
       page_id: page.id,
       section_id: section.id,
       user: user,
       users: Presence.list_presences(topic),
       posts: posts,
       collab_space_config: collab_space_config,
       changeset: Collaboration.change_post(%Collaboration.Post{})
     )}
  end

  def render(assigns) do
    ~F"""
      {#if not is_nil(@collab_space_config) and Map.get(@collab_space_config, :status) == :enabled}
        {render_modal(assigns)}
        <div class="chatroom col-12">
          <div class="row">
            <div class="col-8">
              <div class="text-center"><h4>{@topic}</h4></div>
              <div class="container mt-5">
                  <div class="accordion" id="accordion">
                    {#for post <- @posts}
                      <Post post={post} changeset={@changeset} selected={@selected} selected_reply={@selected_reply} user={@user} set_selected="set_selected" set_selected_reply="set_selected_reply" typing="typing" stop_typing="stop_typing" create_post="create_post"/>
                    {/for}
                  </div>
                  <Input id="input_post" changeset={@changeset} button_text={"Post"} typing="typing" stop_typing="stop_typing" create_post="create_post"/>
              </div>
            </div>
            <div class="col-4">
              <div class="members list-group">
                <ul>
                  <div class="list-group-item active">
                    <h4>Active users <strong>({length(@users)})</strong></h4>
                  </div>
                  <div class="list-group-item">
                    {#for user <- @users}
                      <p>{user.first_name} <strong>{if user.typing do "is typing..." end}</strong></p>
                    {/for}
                  </div>
                </ul>
              </div>
            </div>
          </div>
        </div>
      {/if}
    """
  end

  def handle_event(
        "create_post",
        %{
          "post" => %{
            "content" => %{"message" => message},
            "parent_post_id" => parent_post_id,
            "thread_root_id" => thread_root_id
          }
        },
        socket
      ) do
    case Collaboration.create_post(%{
           content: %{message: message},
           user_id: socket.assigns.user.id,
           section_id: socket.assigns.section_id,
           resource_id: socket.assigns.page_id,
           parent_post_id: parent_post_id,
           thread_root_id: thread_root_id
         }) do
      {:ok, _} ->
        posts = {:updated_post, get_posts(%{status: :approved})}

        PubSub.broadcast(
          Oli.PubSub,
          socket.assigns.topic,
          posts
        )

        {:noreply, assign(socket, selected: thread_root_id, selected_reply: "")}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Could not insert comment"
         )}
    end
  end

  def handle_event("display_edit_modal", %{"id_post" => id_post}, socket) do
    post = Collaboration.get_post_by(%{id: id_post})

    changeset =
      post
      |> Collaboration.change_post()

    modal_assigns = %{
      id: "edit_post_modal",
      on_click: "edit_post",
      changeset: changeset
    }

    modal = fn assigns ->
      ~F"""
        <EditModal {...@modal_assigns} />
      """
    end

    {:noreply,
     show_modal(
       socket,
       modal,
       modal_assigns: modal_assigns,
       post: post
     )}
  end

  def handle_event(
        "edit_post",
        %{"post" => %{"content" => %{"message" => message}}},
        socket
      ) do
    case Collaboration.update_post(socket.assigns.post, %{"content" => %{"message" => message}}) do
      {:ok, _} ->
        posts = {:updated_post, get_posts(%{status: :approved})}

        PubSub.broadcast(
          Oli.PubSub,
          socket.assigns.topic,
          posts
        )

        {:noreply, hide_modal(socket, modal_assigns: nil)}

      {:error, %Ecto.Changeset{} = _changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Could not edit comment"
         )}
    end
  end

  def handle_event("typing", _value, socket = %{assigns: %{user: _user}}) do
    # Presence.update_presence(self(), topic, user.id, %{typing: true})
    {:noreply, socket}
  end

  def handle_event(
        "stop_typing",
        %{"value" => _value},
        socket = %{assigns: %{user: _user}}
      ) do
    # Presence.update_presence(self(), topic, user.id, %{typing: false})
    {:noreply, socket}
  end

  def handle_event("set_selected", %{"id" => value}, socket) do
    {:noreply, assign(socket, selected: value)}
  end

  def handle_event("set_selected_reply", %{"id" => value}, socket) do
    {:noreply, assign(socket, selected_reply: value)}
  end

  def handle_info({:updated_post, updated_posts}, socket) do
    {:noreply, assign(socket, posts: updated_posts)}
  end

  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply,
     assign(socket,
       users: Presence.list_presences(topic)
     )}
  end

  defp default_user_presence_payload(user) do
    %{
      typing: false,
      first_name: user.name,
      email: user.email,
      user_id: user.id
    }
  end

  # defp random_color do
  #   hex_code =
  #     ColorStream.hex()
  #     |> Enum.take(1)
  #     |> List.first()

  #   "##{hex_code}"
  # end

  # def username_colors(chat) do
  #   Enum.map(chat.messages, fn message -> message.user end)
  #   |> Enum.map(fn user -> user.email end)
  #   |> Enum.uniq()
  #   |> Enum.into(%{}, fn email -> {email, random_color()} end)
  # end
end
