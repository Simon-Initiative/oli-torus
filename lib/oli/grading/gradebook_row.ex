defmodule Oli.Grading.GradebookRow do
  alias Oli.Grading.GradebookScore

  @enforce_keys [:user, :scores]
  defstruct [:user, :scores]

  @type t() :: %__MODULE__{
          user: User.t(),
          scores: [
            %GradebookScore{}
          ]
        }
end
