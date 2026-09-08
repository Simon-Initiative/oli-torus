defmodule Oli.Experiments.Policies.PolicyAssignment do
  @moduledoc """
  Policy-selected assignment outcome.
  """

  defstruct [:condition_id, :condition_code, :policy_version, metadata: %{}]

  @type t :: %__MODULE__{}
end
