defmodule Oli.Grading.LineItem do


  @derive Jason.Encoder
  @enforce_keys [:scoreMaximum, :label, :resourceId]
  defstruct [:id, :scoreMaximum, :label, :resourceId]

  @type t() :: %__MODULE__{
    id: String.t(),
    scoreMaximum: float,
    label: String.t(),
    resourceId: String.t()
  }
end
