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
      Jason.encode(%{description: contents.message, subject: contents.subject,
        email: contents.email, priority: 1, status: 2})

    timeout = System.get_env("FRESHDESK_CALL_TIMEOUT")

    result =
      with {:ok, response} <- HTTPoison.post(url, body, @headers),
           {:ok, data} <- Jason.decode(response.body)
        do
        {:ok, data}
      end
      IO.puts "Result from freshdesk api call #{inspect result}"
    {:ok, "help ticket created"}
  end

end
