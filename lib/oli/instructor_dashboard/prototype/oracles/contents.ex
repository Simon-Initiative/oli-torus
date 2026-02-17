defmodule Oli.InstructorDashboard.Prototype.Oracles.Contents do
  @moduledoc """
  Prototype contents oracle returning unit/module structure.
  """

  @behaviour Oli.InstructorDashboard.Prototype.Oracle

  alias Oli.InstructorDashboard.Prototype.MockData

  @impl true
  def key, do: :contents

  @impl true
  def load(_scope, _opts) do
    {:ok, %{units: MockData.units()}}
  end
end
