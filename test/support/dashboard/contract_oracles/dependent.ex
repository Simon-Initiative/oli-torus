defmodule Oli.Dashboard.ContractOracles.Dependent do
  @moduledoc false

  use Oli.Dashboard.Oracle

  @impl true
  def key, do: :oracle_contract_dependent

  @impl true
  def version, do: 1

  @impl true
  def requires, do: [:oracle_contract_prerequisite]

  @impl true
  def load(_context, opts) do
    prerequisite_payload =
      opts
      |> Keyword.get(:inputs, %{})
      |> Map.get(:oracle_contract_prerequisite)

    case prerequisite_payload do
      %{prerequisite_value: value} ->
        {:ok, %{dependent_value: "uses_#{value}"}}

      _ ->
        {:error, {:missing_prerequisite_input, :oracle_contract_prerequisite}}
    end
  end
end
