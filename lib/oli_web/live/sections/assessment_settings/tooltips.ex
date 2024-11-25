defmodule OliWeb.Sections.AssessmentSettings.Tooltips do
  def for(:index), do: "Position that this assessment appears within the course materials"
  def for(:name), do: "The name of the assessment, as it appears to the student"
  def for(:available_date), do: "The available date and time for the assessment"
  def for(:due_date), do: "The due date and time for the assessment"
  def for(:max_attempts), do: "The maximum number of times a student can attempt the assessment"
  def for(:time_limit), do: "A time limit, in minutes, that the student has for each attempt"

  def for(:late_policy),
    do:
      "Select how the system should handle student attempts and submissions after the due date. If set to “disallow late submit and late submit”, the system will automatically submit an attempt at the deadline."

  def for(:late_submit),
    do:
      "Whether or not to allow submissions past the due date or time limit. If set to disallow the system will automatically submit an attempt at the deadline"

  def for(:late_start),
    do: "Whether or not to allow a student to start a new attempt after the due date"

  def for(:scoring_strategy_id),
    do: "How the system will score multiple attempts for an assessment"

  def for(:grace_period),
    do: "The number of minutes after the deadline that the student can submit without penalty"

  def for(:retake_mode),
    do:
      "Targeted retakes allows the student to retake only the questions they missed on a previous attempt"

  def for(:assessment_mode),
    do: "How the system will present questions to students"

  def for(:feedback_mode),
    do: "Whether or not to allow the student to see question feedback and scores after an attempt"

  def for(:review_submission),
    do: "Whether or not a student can review their submission after submitting an attempt"

  def for(:password), do: "A password that the student must enter to access the assessment"

  def for(:exceptions_count),
    do: "The number of student specific exceptions defined for this assessment"
end
