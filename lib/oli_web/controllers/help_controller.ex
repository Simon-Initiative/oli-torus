defmodule OliWeb.HelpController do
  use OliWeb, :controller

  alias OliWeb.Common.{SessionContext, Utils}

  require Logger

  alias Oli.Help.HelpContent

  def create(conn, params) do
    dispatcher = Application.fetch_env!(:oli, :help)[:dispatcher]

    with {:ok, true} <- validate_recapture(Map.get(params, "g-recaptcha-response", "")),
         {:ok, content_params} <- additional_help_context(conn, Map.get(params, "help")),
         {:ok, help_content} <- HelpContent.parse(content_params),
         {:ok, _} <- Oli.Help.Dispatcher.dispatch(dispatcher, help_content) do
      json(conn, %{
        "result" => "success",
        "info" => "Your help request has been successfully submitted"
      })
    else
      {:error, message} ->
        Logger.error("Error when processing help message #{inspect(message)}")
        error(conn, 500, "We are unable to forward your help request at the moment")
    end
  end

  defp validate_recapture(recaptcha) do
    case Oli.Utils.Recaptcha.verify(recaptcha) do
      {:success, true} -> {:ok, true}
      {:success, false} -> {:error, "reCaptcha failure"}
    end
  end

  defp additional_help_context(conn, params) do
    user_agent = Enum.at(get_req_header(conn, "user-agent"), 0)
    accept = Enum.at(get_req_header(conn, "accept"), 0)
    accept_language = Enum.at(get_req_header(conn, "accept-language"), 0)

    user_agent = if user_agent === nil, do: "", else: user_agent
    accept = if accept === nil, do: "", else: accept
    accept_language = if accept_language === nil, do: "", else: accept_language

    remote_ip =
      conn.remote_ip
      |> Tuple.to_list()
      |> Enum.join(".")

    datetime = Timex.now(Timex.Timezone.local())

    content_params =
      Map.merge(
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

    current_user = conn.assigns[:current_user]

    if current_user do
      # :TODO: find a way to reliably get roles in both authoring and delivery contexts
      email = if current_user.email == nil, do: " ", else: current_user.email

      given_name =
        if current_user.given_name == nil,
          do: " ",
          else: current_user.given_name

      family_name =
        if current_user.family_name == nil,
          do: " ",
          else: current_user.family_name

      context = SessionContext.init(conn)

      {
        :ok,
        Map.merge(
          content_params,
          %{
            "account_email" => email,
            "account_name" => given_name <> " " <> family_name,
            "account_created" => Utils.render_precise_date(current_user, :inserted_at, context)
          }
        )
      }
    else
      {:ok, content_params}
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end
