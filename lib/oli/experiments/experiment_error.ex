defmodule Oli.Experiments.ExperimentError do
  @moduledoc """
  Public error returned from the experiments context.
  """

  @enforce_keys [:type, :message]
  defstruct [:type, :message, details: %{}]

  @type error_type ::
          :not_found
          | :invalid_scope
          | :invalid_state
          | :invalid_condition
          | :conflict
          | :persistence_error

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          details: map()
        }
end
