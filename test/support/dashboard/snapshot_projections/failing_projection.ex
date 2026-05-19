defmodule Oli.Dashboard.SnapshotProjections.FailingProjection do
  @moduledoc false

  alias Oli.Dashboard.Snapshot.Contract

  @spec derive(Contract.t(), keyword()) :: {:error, term()}
  def derive(%Contract{}, _opts), do: {:error, {:missing_oracle_payload, :oracle_missing}}
end
