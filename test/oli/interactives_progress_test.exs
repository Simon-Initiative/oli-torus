defmodule Oli.Interactives.ProgressTest do
  use ExUnit.Case, async: true
  import Mox
  alias Oli.Interactives.{Build, EventStream, Progress, Transcript}
  alias Oli.Test.MockHTTP
  setup :verify_on_exit!

  test "SSE framing handles split chunks, CRLF, multiple frames and Unicode" do
    event = %{
      "type" => "agent.session.turn.output_text.delta",
      "item_id" => "m1",
      "delta" => "Température"
    }

    bytes = "event: output\r\ndata: #{Jason.encode!(event)}\r\n\r\n"
    split = byte_size(bytes) - 5
    <<first::binary-size(split), last::binary>> = bytes
    assert {rest, []} = EventStream.decode(first)
    assert {"", [^event, ^event]} = EventStream.decode(rest <> last <> bytes)
  end

  test "recovered final items supersede buffered deltas and tool output is visible without reasoning or input" do
    message = %{
      "id" => "m1",
      "type" => "message",
      "role" => "assistant",
      "status" => "completed",
      "content" => [%{"type" => "output_text", "text" => "Testing the lab"}]
    }

    state =
      Transcript.restore([
        %{
          "id" => "user",
          "type" => "message",
          "role" => "user",
          "content" => [%{"type" => "input_text", "text" => "Author prompt"}]
        },
        %{
          "id" => "reason",
          "type" => "reasoning",
          "summary" => [%{"text" => "Internal reasoning"}]
        },
        message,
        %{
          "id" => "cmd",
          "type" => "command_execution",
          "command" => "node test.cjs",
          "output" => "PASS",
          "status" => "completed"
        }
      ])

    state =
      Transcript.apply(state, %{
        "type" => "agent.session.turn.output_text.delta",
        "item_id" => "m1",
        "delta" => "duplicate"
      })

    assert Transcript.text(state) == "Testing the lab\n\n$ node test.cjs\nPASS"
  end

  test "live text and command deltas update in place and completed content replaces partial text" do
    state =
      Transcript.new()
      |> Transcript.apply(%{
        "type" => "agent.session.turn.output_text.delta",
        "item_id" => "m",
        "delta" => "Making"
      })
      |> Transcript.apply(%{
        "type" => "agent.session.turn.output_text.delta",
        "item_id" => "m",
        "delta" => " a chart"
      })

    assert Transcript.text(state) == "Making a chart"

    state =
      Transcript.apply(state, %{
        "type" => "agent.session.turn.output_text.done",
        "item_id" => "m",
        "text" => "Chart ready"
      })

    state =
      Transcript.apply(state, %{
        "type" => "agent.output.command_execution_output.delta",
        "item_id" => "cmd",
        "delta" => "Tests passed"
      })

    assert Transcript.text(state) =~ "Chart ready"
    assert Transcript.text(state) =~ "Tests passed"
    refute Transcript.text(state) =~ "Making"
  end

  test "reconnection restores history without waiting for quiet stream headers and disconnect stops the reader" do
    parent = self()

    expect(MockHTTP, :request, fn :get, url, _, _, _ ->
      assert url =~ "/items?"
      assert_receive {:reader, reader}
      send(parent, {:reader_seen, reader})

      {:ok,
       %HTTPoison.Response{
         status_code: 200,
         body:
           Jason.encode!(%{
             "data" => [
               %{
                 "id" => "prior",
                 "type" => "message",
                 "role" => "assistant",
                 "status" => "completed",
                 "content" => [%{"type" => "output_text", "text" => "Prior progress"}]
               }
             ]
           })
       }}
    end)

    quiet_reader = fn _, _, _ ->
      send(parent, {:reader, self()})

      receive do
      after
        30_000 -> :closed
      end
    end

    emit = fn sink, _event, data ->
      case String.contains?(data[:text] || "", "Prior progress") do
        true ->
          send(parent, :recovered)
          {:error, :closed}

        false ->
          {:ok, sink}
      end
    end

    assert :sink =
             Progress.follow(%Build{session_id: "sess_quiet", status: "running"}, :sink, emit,
               api_key: "test-key",
               http_client: MockHTTP,
               stream_reader: quiet_reader
             )

    assert_receive :recovered
    assert_receive {:reader_seen, reader}
    refute Process.alive?(reader)
  end
end
