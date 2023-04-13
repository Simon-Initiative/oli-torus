defmodule Oli.LiveSessionPlugs.SetCurrentAuthor do
  import Phoenix.Component, only: [assign: 2]

  def on_mount(:default, _params, %{"current_author_id" => current_author_id}, socket) do
    socket = assign(socket, current_author: Oli.Accounts.get_author(current_author_id))

    {:cont, socket}
  end
end
