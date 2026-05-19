defmodule Oli.InstructorDashboard.Oracles.Placeholder.Engagement do
  @moduledoc """
  Placeholder engagement oracle used for lane-1 contract composition.
  """

  use Oli.Dashboard.Oracle

  @impl true
  def key, do: :oracle_instructor_engagement

  @impl true
  def version, do: 1

  @impl true
  def load(_context, _opts) do
    {:ok, %{status: :placeholder, oracle: :engagement}}
  end
end
