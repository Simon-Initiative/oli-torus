defmodule OliWeb.HelpController do
  use OliWeb, :controller

  alias Oli.Help.HelpContent

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    render_help_page(conn, "index.html", title: "Help")
  end

  def create(conn, params) do
    with {:ok, :true} <- validate_recapture(Map.get(params, "g-recaptcha-response")),
         {:ok, help_content} <- HelpContent.parse(params),
         {:ok, _} <- Oli.Help.Dispatcher.dispatch(Application.fetch_env!(:oli, :help)[:dispatcher], help_content)
      do
      conn
      |> put_flash(:ok, "Your help request has been successfully submitted")
      |> redirect(to: Routes.help_path(conn, :index))
    else
      {:error, message} ->
        conn
        |> put_flash(:error, "Help request failed, please try again")
        |> redirect(to: Routes.help_path(conn, :index))
    end

  end

  defp validate_recapture(recaptcha) do
    case Oli.Utils.Recaptcha.verify(recaptcha) do
      {:success, :true} -> {:ok, :true}
      {:success, :false} -> {:error, "reCaptcha failure"}
    end
  end

  defp render_help_page(conn, page, keywords) do
    render conn, page, Keyword.put_new(keywords, :active, :help)
  end

end
