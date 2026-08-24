defmodule Oli.LearningModel.LktAoa.BatchResult do
  @moduledoc """
  Aggregate result for an LKT-AOA batch application.

  This struct is intentionally safe for worker flow control and telemetry: it
  contains bounded counts only, never learner identifiers, GUIDs, responses, or
  parameter payloads.
  """

  @enforce_keys [
    :status,
    :input_attempt_count,
    :claimed_attempt_count,
    :contribution_count,
    :affected_state_count,
    :new_evidence_count
  ]
  defstruct [
    :status,
    :input_attempt_count,
    :claimed_attempt_count,
    :contribution_count,
    :affected_state_count,
    :new_evidence_count
  ]

  @type status :: :applied | :skipped | :noop

  @type t :: %__MODULE__{
          status: status(),
          input_attempt_count: non_neg_integer(),
          claimed_attempt_count: non_neg_integer(),
          contribution_count: non_neg_integer(),
          affected_state_count: non_neg_integer(),
          new_evidence_count: non_neg_integer()
        }

  @spec new(status(), keyword(non_neg_integer())) :: t()
  def new(status, counts \\ []) when status in [:applied, :skipped, :noop] do
    counts =
      Enum.map(counts, fn {key, value} when is_integer(value) and value >= 0 -> {key, value} end)

    %__MODULE__{
      status: status,
      input_attempt_count: Keyword.get(counts, :input_attempt_count, 0),
      claimed_attempt_count: Keyword.get(counts, :claimed_attempt_count, 0),
      contribution_count: Keyword.get(counts, :contribution_count, 0),
      affected_state_count: Keyword.get(counts, :affected_state_count, 0),
      new_evidence_count: Keyword.get(counts, :new_evidence_count, 0)
    }
  end
end
