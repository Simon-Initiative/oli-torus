defmodule OliWeb.HelpController do
  use OliWeb, :controller

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    render_invite_page(conn, "index.html", title: "Help")
  end

  def create(conn, %{"email" => email, "g-recaptcha-response" => g_recaptcha_response}) do

    case Oli.Utils.Recaptcha.verify(g_recaptcha_response) do
      {:success, :true} ->
        conn
        |> redirect(to: Routes.invite_path(conn, :index))
      {:success, :false} ->
        conn
        |> put_flash(:error, "reCaptcha failed, please try again")
        |> redirect(to: Routes.invite_path(conn, :index))
    end
  end

  defp render_invite_page(conn, page, keywords) do
    render conn, page, Keyword.put_new(keywords, :active, :invite)
  end

end
