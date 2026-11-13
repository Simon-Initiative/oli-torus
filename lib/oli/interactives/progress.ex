defmodule Oli.Interactives.Progress do
  @moduledoc "Reconnecting author output: saved provider items plus live SSE, independent of build execution."
  import Ecto.Query
  alias Oli.Interactives.{AgentsClient, Build, EventStream, Transcript}
  alias Oli.Repo

  @terminal ~w(completed failed cancelled)

  @doc "Preserves bounded visible history before provider-session deletion; read failures keep the previous tail."
  def capture(%{session_id: nil}, _opts), do: :ok

  def capture(build, opts) do
    case history(build.session_id, opts) do
      {:ok, document} ->
        text = Transcript.text(document)
        Repo.update_all(from(b in Build, where: b.id == ^build.id), set: [transcript: text])
        :ok

      _ ->
        :ok
    end
  end

  @doc "Retrieves a bounded recent history, restored in chronological order."
  def history(session_id, opts \\ []) do
    with {:ok, items} <- history_page(session_id, nil, [], 4, Keyword.put(opts, :order, "desc")) do
      {:ok, items |> Enum.reverse() |> Transcript.restore()}
    end
  end

  defp history_page(_, _, items, 0, _), do: {:ok, items}

  defp history_page(id, cursor, items, remaining, opts) do
    with {:ok, page} <- AgentsClient.items_page(id, cursor, opts) do
      items = items ++ (page["data"] || [])

      case {page["has_more"], page["last_id"]} do
        {true, next} when is_binary(next) and next != cursor ->
          history_page(id, next, items, remaining - 1, opts)

        _ ->
          {:ok, items}
      end
    end
  end

  @doc "Streams into an accumulator, restoring saved history; disconnect never cancels remote work."
  def follow(build, sink, emit, opts \\ []) do
    wait_for_session(build, sink, emit, System.monotonic_time(:millisecond) + 45_000, opts)
  end

  defp wait_for_session(build, sink, emit, deadline, opts) do
    case emit.(sink, "output", Map.put(snapshot(build, build.transcript), :restoring, true)) do
      {:error, _} ->
        sink

      {:ok, sink} ->
        cond do
          build.status in @terminal ->
            final_event(sink, emit, "done", %{status: build.status})

          is_binary(build.session_id) ->
            stream(build, sink, emit, deadline, opts)

          System.monotonic_time(:millisecond) >= deadline ->
            sink

          true ->
            receive do
            after
              1000 -> :ok
            end

            case Repo.get(Build, build.id) do
              nil -> sink
              current -> wait_for_session(current, sink, emit, deadline, opts)
            end
        end
    end
  end

  defp stream(build, sink, emit, deadline, opts) do
    owner = self()

    reader =
      Task.Supervisor.async(Oli.TaskSupervisor, fn ->
        stream = Keyword.get(opts, :stream_reader, &EventStream.run/3)

        stream.(
          build.session_id,
          fn event -> send(owner, {:interactive_event, event}) end,
          Keyword.put(opts, :on_open, fn -> send(owner, :interactive_open) end)
        )
      end)

    try do
      # Restore immediately even when the provider delays its SSE headers during quiet work.
      initial_document =
        case history(build.session_id, opts) do
          {:ok, value} -> value
          _ -> Transcript.new()
        end

      initial =
        case Transcript.text(initial_document) do
          "" -> build.transcript
          text -> text
        end

      case emit.(sink, "output", snapshot(build, initial)) do
        {:error, _} ->
          sink

        {:ok, sink} ->
          case await_open(reader) do
            :ok ->
              # Reconcile again after opening; buffered events for finalized items are discarded.
              document =
                case history(build.session_id, opts) do
                  {:ok, value} -> value
                  _ -> initial_document
                end

              {:ok, timer} = :timer.send_interval(200, :interactive_tick)

              try do
                loop(
                  %{
                    build: build,
                    document: document,
                    dirty: true,
                    sink: sink,
                    check_at: System.monotonic_time(:millisecond)
                  },
                  reader,
                  emit,
                  deadline
                )
              after
                :timer.cancel(timer)
              end

            :disconnected ->
              sink
          end
      end
    after
      Task.shutdown(reader, :brutal_kill)
    end
  end

  defp await_open(reader) do
    ref = reader.ref

    receive do
      :interactive_open -> :ok
      {^ref, _} -> :disconnected
      {:DOWN, ^ref, :process, _, _} -> :disconnected
    after
      12_000 -> :disconnected
    end
  end

  defp loop(state, reader, emit, deadline) do
    ref = reader.ref

    receive do
      {:interactive_event, event} ->
        document = Transcript.apply(state.document, event)

        loop(
          %{state | document: document, dirty: state.dirty or document != state.document},
          reader,
          emit,
          deadline
        )

      :interactive_tick ->
        tick(state, reader, emit, deadline)

      {^ref, _} ->
        final_event(
          state.sink,
          emit,
          "output",
          snapshot(state.build, Transcript.text(state.document))
        )

      {:DOWN, ^ref, :process, _, _} ->
        final_event(
          state.sink,
          emit,
          "output",
          snapshot(state.build, Transcript.text(state.document))
        )
    end
  end

  defp tick(state, reader, emit, deadline) do
    now = System.monotonic_time(:millisecond)

    build =
      case now >= state.check_at do
        true -> Repo.get(Build, state.build.id)
        false -> state.build
      end

    cond do
      is_nil(build) ->
        state.sink

      build.status in @terminal ->
        text =
          case build.transcript do
            "" -> Transcript.text(state.document)
            value -> value
          end

        sink = final_event(state.sink, emit, "output", snapshot(build, text))
        final_event(sink, emit, "done", %{status: build.status})

      now >= deadline ->
        state.sink

      true ->
        result =
          cond do
            state.dirty or build.status != state.build.status ->
              text =
                case Transcript.text(state.document) do
                  "" -> build.transcript
                  value -> value
                end

              emit.(state.sink, "output", snapshot(build, text))

            now >= state.check_at ->
              emit.(state.sink, "ping", %{})

            true ->
              {:ok, state.sink}
          end

        case result do
          {:error, _} ->
            state.sink

          {:ok, sink} ->
            check_at =
              case now >= state.check_at do
                true -> now + 2_000
                false -> state.check_at
              end

            loop(
              %{state | build: build, dirty: false, check_at: check_at, sink: sink},
              reader,
              emit,
              deadline
            )
        end
    end
  end

  defp final_event(sink, emit, event, data) do
    case emit.(sink, event, data) do
      {:ok, sink} -> sink
      _ -> sink
    end
  end

  defp snapshot(build, text) do
    stage =
      case build.status do
        "queued" ->
          "Queued. Preparing your agent session…"

        "launching" ->
          "Starting the hosted workspace…"

        "running" ->
          case build.handoff["turn_id"] do
            nil -> "Agent working"
            _ -> "Validating and saving the generated bundle…"
          end

        "cancelling" ->
          "Stopping the agent session…"

        "completed" ->
          "Complete. The experience is saved."

        "cancelled" ->
          "Cancelled."

        "failed" ->
          "The session stopped: #{build.error}"
      end

    %{
      status: build.status,
      text:
        stage <>
          case text do
            "" -> ""
            _ -> "\n\n" <> text
          end
    }
  end
end
