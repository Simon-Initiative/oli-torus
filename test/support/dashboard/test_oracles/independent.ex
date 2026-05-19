defmodule Oli.Dashboard.TestOracles.Independent do
  use Oli.Dashboard.Oracle

  @impl true
  def key, do: :oracle_independent

  @impl true
  def version, do: 1

  @impl true
  def load(_context, _opts), do: {:ok, %{name: :independent}}
end
