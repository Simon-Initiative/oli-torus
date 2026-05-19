defmodule Oli.InstructorDashboard.Recommendations.LiveSync do
  @moduledoc """
  Coordinates PubSub topics for live recommendation lifecycle updates.

  The recommendation pipeline persists the source-of-truth state in the database,
  while this module broadcasts lightweight `:generating_started` and `:updated`
  events keyed by section and dashboard scope so remounted LiveViews can
  reconcile without recomputing the same recommendation.
  """

  alias Oli.Dashboard.Scope
  alias Phoenix.PubSub

  @pubsub Oli.PubSub

  @doc """
  Returns the PubSub topic used for recommendation updates within a section/scope pair.
  """
  @spec topic(pos_integer(), String.t()) :: String.t()
  def topic(section_id, scope_selector)
      when is_integer(section_id) and is_binary(scope_selector) do
    "instructor_dashboard:recommendation:#{section_id}:#{scope_selector}"
  end

  @doc """
  Normalizes a dashboard scope into the stable selector used by recommendation PubSub topics.
  """
  @spec scope_selector(Scope.t()) :: String.t()
  def scope_selector(%Scope{container_type: :course}), do: "course"

  def scope_selector(%Scope{container_type: :container, container_id: id}) when is_integer(id) do
    "container:#{id}"
  end

  def scope_selector(_), do: "course"

  @doc """
  Broadcasts that recommendation generation has started for the given section and scope.
  """
  @spec broadcast_generating_started(pos_integer(), Scope.t(), map()) :: :ok
  def broadcast_generating_started(section_id, %Scope{} = scope, recommendation_payload)
      when is_integer(section_id) and is_map(recommendation_payload) do
    selector = scope_selector(scope)

    PubSub.broadcast(
      @pubsub,
      topic(section_id, selector),
      {:instructor_dashboard_recommendation, :generating_started, section_id, selector,
       recommendation_payload}
    )
  end

  @doc """
  Broadcasts the latest persisted recommendation payload for the given section and scope.
  """
  @spec broadcast_updated(pos_integer(), Scope.t(), map()) :: :ok
  def broadcast_updated(section_id, %Scope{} = scope, recommendation_payload)
      when is_integer(section_id) and is_map(recommendation_payload) do
    selector = scope_selector(scope)

    PubSub.broadcast(
      @pubsub,
      topic(section_id, selector),
      {:instructor_dashboard_recommendation, :updated, section_id, selector,
       recommendation_payload}
    )
  end
end
