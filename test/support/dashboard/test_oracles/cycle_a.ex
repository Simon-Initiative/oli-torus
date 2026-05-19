defmodule Oli.Dashboard.TestOracles.CycleA do
  use Oli.Dashboard.Oracle

  @impl true
  def key, do: :oracle_cycle_a

  @impl true
  def version, do: 1

  @impl true
  def requires, do: [:oracle_cycle_b]

  @impl true
  def load(_context, _opts), do: {:ok, %{name: :cycle_a}}
end
