defmodule Oli.Grading.GradebookScore do
  @enforce_keys [:resource_id, :label, :out_of]
  defstruct [:resource_id, :label, :score, :out_of, :was_late, :index, :title]

  @type t() :: %__MODULE__{
          resource_id: integer,
          label: String.t(),
          score: float | nil,
          out_of: float | nil,
          was_late: boolean | nil,
          index: integer | nil,
          title: String.t()
        }
end
