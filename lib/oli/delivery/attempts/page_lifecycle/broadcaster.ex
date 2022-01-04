defmodule Oli.Delivery.Attempts.PageLifecycle.Broadcaster do
  alias Phoenix.PubSub

  def broadcast_lms_grade_update(resource_access_id, job_id, status) do
    PubSub.broadcast(
      Oli.PubSub,
      message_grade_update(resource_access_id, job_id),
      {:lms_grade_update_result, resource_access_id, job_id, status}
    )
  end

  def subscribe_to_lms_grade_update(resource_access_id, job_id) do
    PubSub.subscribe(Oli.PubSub, message_grade_update(resource_access_id, job_id))
  end

  def unsubscribe_to_lms_grade_update(resource_access_id, job_id) do
    PubSub.unsubscribe(Oli.PubSub, message_grade_update(resource_access_id, job_id))
  end

  def message_grade_update(resource_access_id, job_id) do
    "lms_grade_update_#{resource_access_id}:#{job_id}"
  end
end
