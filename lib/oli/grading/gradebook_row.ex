defmodule Oli.Grading.GradebookRow do
  alias Oli.Grading.GradebookScore

  @enforce_keys [:user_id, :scores]
  defstruct [:user_id, :scores]

  @type t() :: %__MODULE__{
    user_id: String.t(),
    scores: [
      %GradebookScore{}
    ]
  }
end
