defmodule OliWeb.HelpController do
  use OliWeb, :controller

  alias Oli.Help.HelpContent

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    render_help_page(conn, "index.html", title: "Help")
  end

  def create(conn, params) do
    g_recaptcha_response = Map.get(params, "g-recaptcha-response")
    help_content = HelpContent.parse(params)
    IO.puts "help content #{inspect help_content}"
    case Oli.Utils.Recaptcha.verify(g_recaptcha_response) do
      {:success, :true} ->
        help_dispatcher = Application.fetch_env!(:oli, :help)[:dispatcher]
        Oli.Help.Dispatcher.dispatch!(help_dispatcher, help_content)
        conn
        |> put_flash(:ok, "Your help request has been successfully submitted")
        |> redirect(to: Routes.help_path(conn, :index))
      {:success, :false} ->
        conn
        |> put_flash(:error, "reCaptcha failed, please try again")
        |> redirect(to: Routes.help_path(conn, :index))
    end
  end

  defp render_help_page(conn, page, keywords) do
    render conn, page, Keyword.put_new(keywords, :active, :help)
  end

end
