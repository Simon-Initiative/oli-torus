defmodule Oli.Delivery.ScoreAsYouGoNotifications do
  @moduledoc """

  This module encapsulates all broadcasting functionality for score as you go.

  """

  alias Phoenix.PubSub
  require Logger

  @doc """
  Subscribes to changes on score as you go attempt.
  """
  def subscribe(resource_attempt_id) do

    topic = build_topic(resource_attempt_id)
    PubSub.subscribe(Oli.PubSub, topic)

    Logger.info("Subscribing to score as you go messages for topic #{topic}")
  end

  def question_answered(resource_attempt_id, activity_attempt_guid, {score, out_of}) do

    topic = build_topic(resource_attempt_id)

    PubSub.broadcast(
      Oli.PubSub,
      topic,
      {:question_answered, %{score: score, out_of: out_of, activity_attempt_guid: activity_attempt_guid}}
    )

    Logger.info("Broadcasting question answered {#{score}, #{out_of}} for topic #{topic}")
  end

  defp build_topic(resource_attempt_id) do
    "score_as_you_go:#{resource_attempt_id}"
  end

end
