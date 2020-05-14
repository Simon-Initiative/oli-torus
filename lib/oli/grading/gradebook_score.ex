defmodule Oli.Grading.GradebookScore do
  @enforce_keys [:resource_id, :label, :score, :out_of]
  defstruct [:resource_id, :label, :score, :out_of]

  @type t() :: %__MODULE__{
    resource_id: integer,
    label: String.t,
    score: float,
    out_of: float
  }
end
