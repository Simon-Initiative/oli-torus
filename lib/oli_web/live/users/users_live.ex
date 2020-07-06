defmodule OliWeb.Users.UsersLive do

  @moduledoc """
  LiveView implementation of QA view.
  """

  use Phoenix.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Accounts.Author
  alias Oli.Accounts

  alias Oli.Repo

  use OliWeb.Users.Reducers

  def mount(_, %{"current_author_id" => author_id}, socket) do

    author = Repo.get(Author, author_id)

    {:ok, assign(socket, reducers([
      selected: nil,
      author: author,
      users: Accounts.list_authors()
    ]))}
  end

  def selected(state, {"selected", %{"email" => email}}) do
    Enum.find(state.users, fn u -> u.email == email end)
  end


  def render(assigns) do
    ~L"""
    <div class="container">
      <div class="row">
        <div class="col-12">

          <ul>
          <%= for user <- @users do %>
            <li phx-click="select" phx-value-email="<%= user.email %>"><%= user.email %></li>
          <% end %>
          </ul>
        </div>
      </div>
    """
  end


end
