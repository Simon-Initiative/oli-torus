defmodule Oli.Dashboard.SnapshotProjections.PartialProjection do
  @moduledoc false

  alias Oli.Dashboard.Snapshot.Contract

  @spec derive(Contract.t(), keyword()) :: {:partial, map(), term()}
  def derive(%Contract{} = snapshot, _opts) do
    {:partial, %{kind: :partial_projection, request_token: snapshot.request_token},
     {:dependency_unavailable, [:oracle_instructor_support]}}
  end
end
