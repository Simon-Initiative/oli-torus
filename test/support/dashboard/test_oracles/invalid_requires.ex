defmodule Oli.Dashboard.TestOracles.InvalidRequires do
  use Oli.Dashboard.Oracle

  @impl true
  def key, do: :oracle_invalid_requires

  @impl true
  def version, do: 1

  @impl true
  def requires, do: [:missing_oracle]

  @impl true
  def load(_context, _opts), do: {:ok, %{name: :invalid_requires}}
end
