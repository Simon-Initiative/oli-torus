defmodule Oli.Experiments.AnalyticsQuery do
  @moduledoc """
  Scoped query contract for experiment analytics reads.
  """

  alias Oli.Experiments.Scope

  defstruct [:scope, :experiment_id]

  @type t :: %__MODULE__{
          scope: Scope.t(),
          experiment_id: integer() | nil
        }
end
