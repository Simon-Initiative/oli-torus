defmodule Oli.LearningModel.V2.LearningObjectiveParameters do
  @moduledoc """
  LKT-AOA v2 parameters stored on a learning-objective Revision.
  """

  @enforce_keys [:beta_lo]
  defstruct [:beta_lo]

  @type t :: %__MODULE__{beta_lo: float()}
end
