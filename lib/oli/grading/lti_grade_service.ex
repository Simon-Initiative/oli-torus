defmodule Oli.Grading.LtiGradeService do
  @moduledoc """
  Defines the behavior for an LMS adapter required to perform grade services
  """

  @callback product_family_code() :: String.t()
  @callback supported_methods() :: [String.t()]

  # If we need to capture LMS specific information when a basic launch is performed
  # we would do it by calling this callback on launch for the relavant adapter.
  # If an adapter does not need this then it should just be implemented as a no-op.
  @callback basic_launch() :: any()

  @type context_id :: String.t()
  @type lineitem_id :: String.t()

  @typedoc """
  %{
    # Lineitem unique identifier
    "id" => String.t(),

    # Maximum possible score
    "scoreMaximum" => float(),

    # Label to use in the Tool Consumer UI (Gradebook)
    "label" => String.t(),

    # Additional information about the line item; may be used by the tool to identify line items
    # attached to the same resource or resource link (example: grade, originality, participation)
    # maxLength: 256
    "tag" => String.t(),

    # Tool resource identifier for which this line item is receiving scores from
    "resourceId" => String.t(),

    # Id of the tool platform's resource link to which this line item is attached to
    "resourceLinkId" => String.t(),

    "submission" => %{
      # Date and time in ISO 8601 format when a submission can start being submitted by learner
      "startDateTime" => String.t(),

      # Date and time in ISO 8601 format when a submission can last be submitted by learner
      "endDateTime" => String.t(),
  }
  """
  @type lineitem_json :: %{required(String.t()) => String.t() | float()}

  @typedoc """
  %{
    # Recipient of the score, usually a student. Must be present when publishing a score update
    # through Scores.POST operation.
    "userId" => String.t(),

    # Current score received in the tool for this line item and user, in scale with scoreMaximum
    "scoreGiven" => String.t(),

    # Maximum possible score for this result; It must be present if scoreGiven is present.
    "scoreMaximum" => String.t(),

    # Comment visible to the student about this score.
    "comment" => String.t(),

    # Date and time in ISO 8601 format when the score was modified in the tool. Should use subsecond precision.
    "timestamp" => String.t(),

    # Indicate to the tool platform the status of the user towards the activity's completion.
    "activityProgress" => String.t(),

    # Indicate to the platform the status of the grading process, including allowing to inform when
    # human intervention is needed. A value other than FullyGraded may cause the tool platform to
    # ignore the scoreGiven value if present.
    "gradingProgress" => String.t(),
  }
  """
  @type score_json :: %{required(String.t()) => String.t()}

  @callback get_lineitems(context_id()) :: any()
  @callback add_lineitem(context_id(), lineitem_json()) :: any()
  @callback get_lineitem(context_id(), lineitem_id()) :: any()
  @callback change_lineitem(context_id(), lineitem_json()) :: any()
  @callback remove_lineitem(context_id(), lineitem_id()) :: any()
  @callback get_lineitem_results(context_id(), lineitem_id()) :: any()
  @callback add_lineitem_score(context_id(), lineitem_id(), score_json()) :: any()

  @type http_method :: String.t
  @type url :: String.t
  @type body :: String.t
  @type headers :: %{optional(String.t) => String.t}
  @spec authenticated_fetch(http_method, url, body, headers) :: any()
  def authenticated_fetch(http_method, url, body, headers) do
    # TODO: implement me
  end

  @spec refresh_api_token() :: any()
  def refresh_api_token() do
    # TODO: implement me
  end

  def get_lineitems(context_id, adapter) do
    adapter.get_lineitems(context_id)
  end

  def add_lineitem(context_id, lineitem_json, adapter) do
    adapter.add_lineitem(context_id, lineitem_json)
  end

  def get_lineitem(context_id, lineitem_id, adapter) do
    adapter.get_lineitem(context_id, lineitem_id)
  end

  def change_lineitem(context_id, lineitem, adapter) do
    adapter.change_lineitem(context_id, lineitem)
  end

  def remove_lineitem(context_id, lineitem_id, adapter) do
    adapter.remove_lineitem(context_id, lineitem_id)
  end

  def get_lineitem_results(context_id, lineitem_id, adapter) do
    adapter.get_lineitem_results(context_id, lineitem_id)
  end

  def add_lineitem_score(context_id, lineitem_id, score_json, adapter) do
    adapter.add_lineitem_score(context_id, lineitem_id, score_json)
  end
end
