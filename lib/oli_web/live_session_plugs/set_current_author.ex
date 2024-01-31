defmodule OliWeb.LiveSessionPlugs.SetCurrentAuthor do
  @moduledoc """
  This plug is responsible for setting the current author in the socket assigns, so it expects
  to have a current_author_id in the session.
  If there is no current_author_id  we redirect the author to the login.
  """
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [redirect: 2]

  def on_mount(:default, _params, %{"current_author_id" => current_author_id}, socket) do
    socket = assign(socket, current_author: Oli.Accounts.get_author(current_author_id))

    {:cont, socket}
  end

  def on_mount(_, _params, _session, socket) do
    # when there is no current_author_id in the session we redirect the user to the login
    {:halt, redirect(socket, to: ~p"/authoring/session/new")}
  end
end
