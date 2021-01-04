defmodule Oli.Help.Providers.FreshdeskHelp do
  @behaviour Oli.Help.Dispatcher

  alias Oli.Help.HelpContent

  @headers [
    {"Content-type", "application/json"},
    {"Accept", "application/json"},
    {"Authorization", "Basic " <> Base.encode64(System.get_env("FRESHDESK_API_KEY"))}
  ]

  @impl Oli.Help.Dispatcher
  def dispatch(%HelpContent{} = contents) do
    url = System.get_env("FRESHDESK_API_URL")

    {:ok, body} =
      Jason.encode(
        %{
          name: contents.full_name,
          description: contents.message,
          subject: HelpContent.get_subject(contents.subject),
          email: contents.email,
          priority: 1,
          status: 2
        }
      )

    timeout = System.get_env("FRESHDESK_CALL_TIMEOUT")

    case HTTPoison.post(url, body, @headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      {:ok, %HTTPoison.Response{body: body}} ->
        {:error, body}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

end
