defmodule Oli.Grading.Score do

  @derive Jason.Encoder
  @enforce_keys [:timestamp, :scoreGiven, :scoreMaximum, :comment, :activityProgress, :gradingProgress, :userId]
  defstruct [:timestamp, :scoreGiven, :scoreMaximum, :comment, :activityProgress, :gradingProgress, :userId]

  @type t() :: %__MODULE__{
    timestamp: String.t(),
    scoreGiven: float,
    scoreMaximum: float,
    comment: String.t(),
    activityProgress: String.t(),
    gradingProgress: String.t(),
    userId: String.t()
  }
end
