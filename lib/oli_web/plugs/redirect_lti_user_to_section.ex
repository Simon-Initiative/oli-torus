defmodule Oli.Plugs.RedirectLtiUserToSection do
  @moduledoc """
  Ensures that an LTI user is redirected to the correct section.
  """
  use OliWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    is_admin = conn.assigns[:is_admin]

    with false <- is_admin,
         false <- user.independent_learner do
      # Redirect to the delivery index route which will redirect to the correct section
      conn
      |> redirect(to: ~p"/course")
      |> halt()
    else
      _ -> conn
    end
  end
end
