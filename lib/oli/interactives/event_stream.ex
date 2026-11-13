defmodule Oli.Interactives.EventStream do
  @moduledoc "Bounded SSE framing and the server-only OpenAI session event transport."

  @doc "Decodes complete SSE data frames, retaining a partial frame for the next chunk."
  def decode(buffer) do
    frames = String.split(String.replace(buffer, "\r\n", "\n"), "\n\n")
    {complete, [rest]} = Enum.split(frames, -1)

    events =
      Enum.flat_map(complete, fn frame ->
        data =
          frame
          |> String.split("\n")
          |> Enum.filter(&String.starts_with?(&1, "data:"))
          |> Enum.map_join(
            "\n",
            &(String.replace_prefix(&1, "data:", "") |> String.trim_leading())
          )

        case Jason.decode(data) do
          {:ok, event} when is_map(event) -> [event]
          _ -> []
        end
      end)

    {rest, events}
  end

  @doc "Consumes live provider events until disconnect; killing the reader closes its HTTP connection."
  def run(session_id, callback, opts \\ []) do
    key = Keyword.get(opts, :api_key, System.get_env("OPENAI_API_KEY"))

    case is_binary(key) and String.trim(key) != "" do
      true ->
        url =
          "https://api.openai.com/v1/agents/sessions/#{URI.encode(session_id, &URI.char_unreserved?/1)}/events?stream=true"

        headers = [
          {"authorization", "Bearer " <> key},
          {"openai-beta", "agents=v1"},
          {"accept", "text/event-stream"}
        ]

        case HTTPoison.get(url, headers,
               stream_to: self(),
               async: :once,
               recv_timeout: 60_000,
               timeout: 10_000,
               follow_redirect: false
             ) do
          {:ok, response} ->
            try do
              receive_events(response, callback, "", Keyword.get(opts, :on_open, fn -> :ok end))
            after
              :hackney.stop_async(response.id)
            end

          _ ->
            :disconnected
        end

      false ->
        :disconnected
    end
  end

  defp receive_events(response, callback, buffer, on_open) do
    id = response.id

    receive do
      %HTTPoison.AsyncStatus{id: ^id, code: 200} ->
        on_open.()
        HTTPoison.stream_next(response)
        receive_events(response, callback, buffer, on_open)

      %HTTPoison.AsyncHeaders{id: ^id} ->
        HTTPoison.stream_next(response)
        receive_events(response, callback, buffer, on_open)

      %HTTPoison.AsyncChunk{id: ^id, chunk: chunk} ->
        {rest, events} = decode(buffer <> chunk)

        case byte_size(rest) <= 1_000_000 do
          true ->
            Enum.each(events, callback)
            HTTPoison.stream_next(response)
            receive_events(response, callback, rest, on_open)

          false ->
            :disconnected
        end

      %HTTPoison.AsyncEnd{id: ^id} ->
        :closed

      %HTTPoison.AsyncStatus{id: ^id} ->
        :disconnected

      %HTTPoison.Error{} ->
        :disconnected
    after
      65_000 -> :disconnected
    end
  end
end
