defmodule Oli.Grading.Score do

  @enforce_keys [:timestamp, :scoreGiven, :scoreMaximum, :comment, :activityProgress, :gradingProgess, :userId]
  defstruct [:timestamp, :scoreGiven, :scoreMaximum, :comment, :activityProgress, :gradingProgess, :userId]

  @type t() :: %__MODULE__{
    timestamp: String.t(),
    scoreGiven: float,
    scoreMaximum: float,
    comment: String.t(),
    activityProgress: String.t(),
    gradingProgess: String.t(),
    userId: String.t()
  }
end
