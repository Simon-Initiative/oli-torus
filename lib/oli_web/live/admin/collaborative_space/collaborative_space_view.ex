defmodule OliWeb.Admin.CollaborativeSpace do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias OliWeb.Presence
  alias Phoenix.PubSub
  alias Oli.Resources.Collaboration

  alias OliWeb.Admin.{
    Post,
    Input
  }

  data selected, :string, default: ""
  data selected_reply, :string, default: ""
  data author, :struct
  data users, :list
  data posts, :list

  defp topic(space_id), do: "Space:#{space_id}"

  defp posts_with_replies(filter) do
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

  def mount(_, %{"current_author_id" => author_id} = _session, socket) do
    PubSub.subscribe(Oli.PubSub, topic(123))
    author = Oli.Accounts.get_author(author_id)

    posts = posts_with_replies(%{status: :approved})

    Presence.track_presence(
      self(),
      topic(123),
      author_id,
      default_user_presence_payload(author)
    )

    {:ok,
     assign(socket,
       author: author,
       users: Presence.list_presences(topic(123)),
       posts: posts
     )}
  end

  def render(assigns) do
    ~F"""
      <div class="chatroom col-12">
        <div class="row">
          <div class="col-8">
            <div class="text-center"><h4>{topic(123)}</h4></div>
            <div class="container mt-5">
              <div class="accordion" id="accordion">
                {#for post <- @posts}
                  <Post post={post} selected={@selected} selected_reply={@selected_reply} user={@author} set_selected="set_selected" set_selected_reply="set_selected_reply" typing="typing" stop_typing="stop_typing" create_post="create_post"/>
                {/for}
              </div>
                <Input id="input_post" button_text={"Post"} typing="typing" stop_typing="stop_typing" create_post="create_post"/>
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
    """
  end

  def handle_event(
        "create_post",
        %{
          "message_form" => %{
            "message_text" => message_text,
            "id_parent" => id_parent,
            "id_root" => id_root
          }
        },
        socket
      ) do
    case Collaboration.create_post(%{
           content: %{message: message_text},
           parent_post_id: id_parent,
           thread_root_id: id_root
         }) do
      {:ok, _} ->
        posts = {:updated_post, posts_with_replies(%{status: :approved})}

        PubSub.broadcast(
          Oli.PubSub,
          topic(123),
          posts
        )

        {:noreply, assign(socket, selected: id_root, selected_reply: "")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Could not insert comment"
         )}
    end
  end

  def handle_event("typing", _value, socket = %{assigns: %{author: _user}}) do
    # Presence.update_presence(self(), topic(123), user.id, %{typing: true})
    {:noreply, socket}
  end

  def handle_event(
        "stop_typing",
        %{"value" => _value},
        socket = %{assigns: %{author: _user}}
      ) do
    # Presence.update_presence(self(), topic(123), user.id, %{typing: false})
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
       users: Presence.list_presences(topic(123))
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
