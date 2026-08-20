defmodule Oli.LearningModel.V2.PartParameters do
  @moduledoc """
  LKT-AOA v2 difficulty parameters for one activity part.
  """

  @enforce_keys [:beta_difficulty]
  defstruct [:beta_difficulty]

  @type t :: %__MODULE__{beta_difficulty: float()}
end
