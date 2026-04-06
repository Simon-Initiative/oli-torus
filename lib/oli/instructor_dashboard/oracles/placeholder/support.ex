defmodule Oli.InstructorDashboard.Oracles.Placeholder.Support do
  @moduledoc """
  Placeholder support oracle used for lane-1 contract composition.
  """

  use Oli.Dashboard.Oracle

  @impl true
  def key, do: :oracle_instructor_support

  @impl true
  def version, do: 1

  @impl true
  def requires, do: [:oracle_instructor_progress]

  @impl true
  def load(_context, _opts) do
    {:ok, %{status: :placeholder, oracle: :support}}
  end
end
