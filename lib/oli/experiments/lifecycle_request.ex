defmodule Oli.Experiments.LifecycleRequest do
  @moduledoc """
  Request to transition a native experiment definition lifecycle state.
  """

  alias Oli.Experiments.Scope

  defstruct [:scope, :transitioned_at]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          transitioned_at: DateTime.t() | nil
        }
end
