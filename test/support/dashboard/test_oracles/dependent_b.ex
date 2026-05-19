defmodule Oli.Dashboard.TestOracles.DependentB do
  use Oli.Dashboard.Oracle

  @impl true
  def key, do: :oracle_dep_b

  @impl true
  def version, do: 1

  @impl true
  def requires, do: [:oracle_prereq]

  @impl true
  def load(_context, _opts), do: {:ok, %{name: :dependent_b}}
end
