defmodule Oli.InstructorDashboard.Oracles.Placeholder.Progress do
  @moduledoc """
  Placeholder oracle used for lane-1 contract wiring until tile-specific
  instructor oracles are finalized.
  """

  use Oli.Dashboard.Oracle

  @impl true
  def key, do: :oracle_instructor_progress

  @impl true
  def version, do: 1

  @impl true
  def load(_context, _opts) do
    {:ok, %{status: :placeholder, oracle: :progress}}
  end
end
