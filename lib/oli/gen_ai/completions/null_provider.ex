defmodule Oli.GenAI.Completions.NullProvider do
  @moduledoc """
  A null provider for the completions service that does nothing.
  """

  @behaviour Oli.GenAI.Completions.Provider

  @impl true
  def generate(_messages, _functions, _registered_model) do
    {:ok, "This is a null provider. No generation performed."}
  end

  @impl true
  def stream(_messages, _functions, _registered_model, stream_fn) do
    str = "This is a null provider. No generation performed."
    tokens = String.split(str, " ") ++ ["STOP"]

    total = length(tokens)

    tokens
    |> Stream.with_index()
    |> Stream.each(fn {word, idx} ->
      chunk =
        cond do
          idx == total - 1 ->
            {:tokens_finished}

          true ->
            {:tokens_received, word <> " "}
        end

      # Sleep a random amount milliseconds between 100 and 200
      :rand.seed(
        :exs64,
        {System.os_time(:millisecond), System.unique_integer([:positive]),
         :os.system_time(:millisecond)}
      )

      :rand.uniform(50)
      |> Kernel.+(100)
      |> :timer.sleep()

      stream_fn.(chunk)
    end)
    |> Stream.run()
  end
end
