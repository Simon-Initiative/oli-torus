defmodule Oli.Dashboard.TestOracles.Prerequisite do
  use Oli.Dashboard.Oracle

  @impl true
  def key, do: :oracle_prereq

  @impl true
  def version, do: 1

  @impl true
  def load(_context, _opts), do: {:ok, %{name: :prerequisite}}
end
