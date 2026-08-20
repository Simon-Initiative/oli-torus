defmodule Oli.LearningModel.V2.ActivityParameters do
  @moduledoc """
  LKT-AOA v2 parameters stored on an activity Revision.
  """

  alias Oli.LearningModel.V2.PartParameters

  @enforce_keys [:parts]
  defstruct [:parts]

  @type t :: %__MODULE__{parts: %{String.t() => PartParameters.t()}}
end
