defmodule Oli.Scenarios.Directives.WaitHandler do
  @moduledoc """
  Handles wait directives that pause scenario execution for real elapsed time.
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, WaitDirective}

  def handle(%WaitDirective{} = directive, %ExecutionState{} = state) do
    milliseconds = duration_ms(directive)

    if milliseconds <= 0 do
      {:error, "Wait directive must specify a positive duration"}
    else
      Process.sleep(milliseconds)
      drain_due_auto_submit_jobs()
      {:ok, state}
    end
  end

  defp duration_ms(%WaitDirective{milliseconds: milliseconds}) when is_integer(milliseconds),
    do: milliseconds

  defp duration_ms(%WaitDirective{seconds: seconds}) when is_integer(seconds), do: seconds * 1000

  defp duration_ms(_directive), do: 0

  defp drain_due_auto_submit_jobs do
    if Application.get_env(:oli, Oban)[:testing] == :manual do
      Oban.drain_queue(
        queue: :auto_submit,
        with_scheduled: DateTime.utc_now(),
        with_safety: false
      )
    end
  end
end
