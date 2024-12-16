defmodule Oli.Help.Providers.EmailHelp do
  @behaviour Oli.Help.Dispatcher

  alias Oli.Help.HelpContent

  @impl Oli.Help.Dispatcher
  def dispatch(%HelpContent{} = contents) do
    help_desk_email = System.get_env("HELP_DESK_EMAIL", "test@example.edu")

    email =
      Oli.Email.help_desk_email(
        contents.email,
        help_desk_email,
        HelpContent.get_subject(contents.subject),
        :help_email,
        %{
          message: build_help_message(contents)
        }
      )

    Oli.Mailer.deliver(email)
  end

  defp build_help_message(contents) do
    message =
      "On " <>
        contents.timestamp <>
        ", " <>
        contents.full_name <>
        " <&nbsp;" <>
        contents.email <>
        "&nbsp;>" <>
        " wrote:<br><br>" <>
        contents.message <>
        "<br><br><br>----------------------------------------------" <>
        "<br>Timestamp: " <>
        contents.timestamp <>
        "<br>Ip Address: " <>
        contents.ip_address <>
        "<br>Location: " <>
        contents.location <>
        "<br><br><br> WEB BROWSER" <>
        "<br>User Agent: " <>
        contents.user_agent <>
        "<br>Accept: " <>
        contents.agent_accept <>
        "<br>Language: " <>
        contents.agent_language <>
        "<br><br> CAPABILITIES" <>
        "<br>Cookies Enabled: " <>
        contents.cookies_enabled <>
        "<br><br> USER ACCOUNT" <>
        "<br>Name: " <>
        contents.account_name <>
        "<br>Email: " <>
        contents.account_email <>
        "<br>Created: " <> contents.account_created

    message
    |> String.replace("\r", "")
    |> String.replace("\n", "<br>")
  end
end
