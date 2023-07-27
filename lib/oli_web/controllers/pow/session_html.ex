defmodule OliWeb.Pow.SessionHTML do
  use OliWeb, :html

  embed_templates("session_html/*")

  def render("new.html", assigns) do
    case OliWeb.Pow.PowHelpers.current_pow_config(assigns.conn) do
      Oli.Accounts.Author -> Phoenix.Controller.render(assigns.conn, :author_new, assigns)
      _ -> Phoenix.Controller.render(assigns.conn, :user_new, assigns)
    end
  end
end
