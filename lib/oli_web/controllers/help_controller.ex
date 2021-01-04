defmodule OliWeb.HelpController do
  use OliWeb, :controller

  alias Oli.Help.HelpContent
  alias Oli.Repo

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    render_help_page(conn, "index.html", title: "Help")
  end

  def create(conn, params) do
    user_agent = get_req_header(conn, "user-agent")
    accept = get_req_header(conn, "accept")
    accept_language = get_req_header(conn, "accept-language")
    referer = get_req_header(conn, "referer")
    datetime = Timex.now(Timex.Timezone.local())
    content_params = Map.merge(params, %{"user_agent": user_agent,
      "ip_address": conn.remote_ip, "timestamp": datetime, "agent_accept": accept,
      "agent_language": accept_language, "location": referer})
    current_user = Pow.Plug.current_user(conn)
    if current_user != nil do
      current_user = current_user |> Repo.preload([:system_role])
      IO.puts "Current user details #{inspect current_user}"

      content_params = Map.merge(content_params, %{"account_email": current_user.email,
        "account_name": current_user.given_name <> " " <> current_user.family_name,
        "account_created": current_user.inserted_at, "agent_accept": accept})
    end

    #    :account_role,
    with {:ok, :true} <- validate_recapture(Map.get(params, "g-recaptcha-response")),
         {:ok, help_content} <- HelpContent.parse(content_params),
         {:ok, _} <- Oli.Help.Dispatcher.dispatch(Application.fetch_env!(:oli, :help)[:dispatcher], help_content)
      do
      conn
      |> put_flash(:ok, "Your help request has been successfully submitted")
      |> redirect(to: Routes.help_path(conn, :index))
    else
      {:error, message} -> IO.puts "errors from dispatch #{inspect message}"
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
