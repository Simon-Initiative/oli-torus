defmodule Oli.Dashboard.ContractOracles.Prerequisite do
  @moduledoc false

  use Oli.Dashboard.Oracle

  @impl true
  def key, do: :oracle_contract_prerequisite

  @impl true
  def version, do: 1

  @impl true
  def load(_context, _opts), do: {:ok, %{prerequisite_value: "ready"}}

  @impl true
  def project(payload, _opts), do: payload.prerequisite_value
end
