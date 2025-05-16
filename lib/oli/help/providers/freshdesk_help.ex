defmodule Oli.Help.Providers.FreshdeskHelp do
  @behaviour Oli.Help.Dispatcher

  alias Oli.Help.HelpContent
  alias Oli.Help.RequesterData
  import Oli.HTTP

  require Logger

  @impl Oli.Help.Dispatcher
  def dispatch(%HelpContent{requester_data: %RequesterData{} = requester_data} = contents) do
    url = System.get_env("FRESHDESK_API_URL", "example.edu")
    requester_name = requester_data.requester_name
    requester_email = requester_data.requester_email

    {:ok, body} =
      Jason.encode(%{
        name: requester_name,
        description: build_help_message(contents),
        subject: HelpContent.get_subject(contents.subject) <> "[" <> requester_name <> "]",
        email: requester_email,
        priority: 1,
        status: 2
      })

    headers = [
      {"Content-type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization",
       "Basic " <> Base.encode64(System.get_env("FRESHDESK_API_KEY", "examplekey"))}
    ]

    case http().post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: 201, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{body: body}} ->
        Logger.error(body)

        Logger.error("""
        Error in FreshdeskHelp.dispatch.
        Type: api call, failed with non 200 or 201 status code"
        """)

        {:error, "Error creating Freshdesk help ticket"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error(reason)

        Logger.error("""
        Error in FreshdeskHelp.dispatch."
        """)

        {:error, "Error creating Freshdesk help ticket"}
    end
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
