defmodule OliWeb.Admin.ChatView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias OliWeb.Presence
  alias OliWeb.Common.ChatMessage
  alias Phoenix.PubSub

  data msg, :string, default: ""
  data is_enabled_comment, :boolean, default: false

  defp topic(chat_id), do: "chat:#{chat_id}"

  def mount(_, %{"current_author_id" => author_id} = _session, socket) do
    PubSub.subscribe(Oli.PubSub, topic(123))
    author = Oli.Accounts.get_author(author_id)

    messages = [
      %{
        id: 1,
        text:
          "dui vivamus arcu felis bibendum ut tristique et egestas quis ipsum suspendisse ultrices gravida dictum",
        author: author,
        replies: [%{text: "Reply 1"}]
      },
      %{
        id: 2,
        text:
          "sapien faucibus et molestie ac feugiat sed lectus vestibulum mattis ullamcorper velit sed ullamcorper morbi",
        author: author,
        replies: [%{text: "Reply 2"}]
      }
    ]

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
       messages: messages,
       is_enabled_comment: false
     )}
  end

  def render(assigns) do
    ~F"""
      <div class="chatroom col-12">
        <div class="row">
          <div class="col-8">
            <h4>{topic(123)}</h4>
            <div>
              <ChatMessage messages={@messages} enabled_comment="enabled_comment" is_enabled_comment={@is_enabled_comment}/>
            </div>
            <form for={:message} :on-submit="add_comment" :on-change="typing" autocomplete="off">
              <div class="form-group">
                <input type="text" name={:message} value={@msg} :on-blur="stop_typing" class="form-control" placeholder="Write new message">
              </div>
              <button type="submit" class="btn btn-primary">Post</button>
            </form>
          </div>
          <div class="col-4">
            <div class="members list-group">
              <ul>
                <div class="list-group-item active">
                  <h3>Active users</h3>
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

  def handle_event("enabled_comment", _, socket) do
    {:noreply, assign(socket, :is_enabled_comment, true)}
  end

  def handle_event("add_comment", %{"message" => message}, socket) do
    last_id = List.last(socket.assigns.messages).id

    messages =
      {:updated_message,
       socket.assigns.messages ++
         [
           %{
             id: last_id + 1,
             text: message,
             author: socket.assigns.author,
             replies: []
           }
         ]}

    PubSub.broadcast(
      Oli.PubSub,
      topic(123),
      messages
    )

    {:noreply, assign(socket, :msg, "")}
  end

  def handle_event("typing", _value, socket = %{assigns: %{author: user}}) do
    Presence.update_presence(self(), topic(123), user.id, %{typing: true})
    {:noreply, socket}
  end

  def handle_event(
        "stop_typing",
        value,
        socket = %{assigns: %{author: user}}
      ) do
    Presence.update_presence(self(), topic(123), user.id, %{typing: false})
    {:noreply, assign(socket, :msg, value["value"])}
  end

  def handle_info({:updated_message, updated_messages}, socket) do
    {:noreply, assign(socket, messages: updated_messages)}
  end

  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply,
     assign(socket,
       users: Presence.list_presences(topic(123))
     )}
  end

  # def handle_info(%{event: "message", payload: state}, socket) do
  #   {:noreply, assign(socket, state)}
  # end

  # def handle_event("message", %{"message" => %{"content" => ""}}, socket) do
  #   {:noreply, socket}
  # end

  # def handle_event("message", %{"message" => message_params}, socket) do
  #   chat = Chats.create_message(message_params)
  #   PhatWeb.Endpoint.broadcast_from(self(), topic(chat.id), "message", %{chat: chat})
  #   {:noreply, assign(socket, chat: chat, message: Chats.change_message())}
  # end

  # def handle_event("typing", _value, socket = %{assigns: %{chat: chat, current_user: user}}) do
  #   Presence.update_presence(self(), topic(chat.id), user.id, %{typing: true})
  #   {:noreply, socket}
  # end

  # def handle_event(
  #       "stop_typing",
  #       value,
  #       socket = %{assigns: %{chat: chat, current_user: user, message: message}}
  #     ) do
  #   message = Chats.change_message(message, %{content: value})
  #   Presence.update_presence(self(), topic(chat.id), user.id, %{typing: false})
  #   {:noreply, assign(socket, message: message)}
  # end

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
