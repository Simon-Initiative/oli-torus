defmodule Oli.Dashboard.TestOracles.InvalidKey do
  use Oli.Dashboard.Oracle

  @impl true
  def key, do: :wrong_oracle_key

  @impl true
  def version, do: 1

  @impl true
  def load(_context, _opts), do: {:ok, %{name: :invalid_key}}
end
