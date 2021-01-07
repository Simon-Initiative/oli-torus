defmodule OliWeb.HelpDeliveryController do
  use OliWeb, :controller

  alias Oli.Help.HelpContent

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
#    IO.inspect conn.private |> Map.get(:phoenix_root_layout, false)
    render_help_page(conn, "index.html", title: "Help")
  end

  @spec sent(Plug.Conn.t(), any) :: Plug.Conn.t()
  def sent(conn, _params) do
    render_help_page(conn, "success.html", title: "Help")
  end

  def create(conn, params) do
    with {:ok, :true} <- validate_recapture(Map.get(params, "g-recaptcha-response")),
         {:ok, content_params} <- additional_help_context(conn, params),
         {:ok, help_content} <- HelpContent.parse(content_params),
         {:ok, _} <- Oli.Help.Dispatcher.dispatch(Application.fetch_env!(:oli, :help)[:dispatcher], help_content)
      do
      conn
      |> put_flash(:ok, "Your help request has been successfully submitted")
      |> redirect(to: Routes.help_delivery_path(conn, :sent))
    else
      {:error, _message} ->
                           conn
                           |> put_flash(:error, "Help request failed, please try again")
                           |> redirect(to: Routes.help_delivery_path(conn, :index))
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

  defp additional_help_context(conn, params) do
    user_agent = Enum.at(get_req_header(conn, "user-agent"), 0)
    accept = Enum.at(get_req_header(conn, "accept"), 0)
    accept_language = Enum.at(get_req_header(conn, "accept-language"), 0)
    remote_ip = conn.remote_ip
                |> Tuple.to_list
                |> Enum.join(".")
    datetime = Timex.now(Timex.Timezone.local())
    content_params = Map.merge(
      params,
      %{
        "user_agent" => user_agent,
        "ip_address" => remote_ip,
        "timestamp" => DateTime.to_string(datetime),
        "agent_accept" => accept,
        "agent_language" => accept_language,
        "account_email" => " ",
        "account_name" => " ",
        "account_created" => " "
      }
    )

    current_user = Pow.Plug.current_user(conn)
    if current_user != nil do
      # :TODO: find a way to reliably get roles in both authoring and delivery contexts
      email = if current_user.email == nil, do: " ", else: " "
      given_name = if current_user.given_name == nil, do: " ", else: " "
      family_name = if current_user.family_name == nil, do: " ", else: " "
      account_created_date = DateTime.to_string Timex.Timezone.convert(current_user.inserted_at, Timex.Timezone.local())
      {
        :ok,
        Map.merge(
          content_params,
          %{
            "account_email" => email,
            "account_name" => given_name <> " " <> family_name,
            "account_created" => account_created_date
          }
        )
      }
    else
      {:ok, content_params}
    end
  end

end
