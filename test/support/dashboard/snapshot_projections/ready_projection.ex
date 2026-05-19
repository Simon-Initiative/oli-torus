defmodule Oli.Dashboard.SnapshotProjections.ReadyProjection do
  @moduledoc false

  alias Oli.Dashboard.Snapshot.Contract

  @spec derive(Contract.t(), keyword()) :: {:ok, map()}
  def derive(%Contract{} = snapshot, _opts) do
    {:ok, %{kind: :ready_projection, request_token: snapshot.request_token}}
  end
end
