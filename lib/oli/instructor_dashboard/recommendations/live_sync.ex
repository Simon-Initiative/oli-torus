defmodule Oli.InstructorDashboard.Recommendations.LiveSync do
  @moduledoc false

  alias Oli.Dashboard.Scope
  alias Phoenix.PubSub

  @pubsub Oli.PubSub

  @doc false
  @spec topic(pos_integer(), String.t()) :: String.t()
  def topic(section_id, scope_selector)
      when is_integer(section_id) and is_binary(scope_selector) do
    "instructor_dashboard:recommendation:#{section_id}:#{scope_selector}"
  end

  @doc false
  @spec scope_selector(Scope.t()) :: String.t()
  def scope_selector(%Scope{container_type: :course}), do: "course"

  def scope_selector(%Scope{container_type: :container, container_id: id}) when is_integer(id) do
    "container:#{id}"
  end

  def scope_selector(_), do: "course"

  @doc false
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

  @doc false
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
