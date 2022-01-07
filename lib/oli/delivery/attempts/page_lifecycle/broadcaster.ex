defmodule Oli.Delivery.Attempts.PageLifecycle.Broadcaster do
  alias Phoenix.PubSub

  def broadcast_lms_grade_update(section_id, resource_access_id, job, status, details) do
    PubSub.broadcast(
      Oli.PubSub,
      message_grade_update(section_id, resource_access_id, job.id),
      {:lms_grade_update_result,
       %{
         resource_access_id: resource_access_id,
         job: job,
         status: status,
         details: details
       }}
    )
  end

  def subscribe_to_lms_grade_update(section_id, resource_access_id, job_id) do
    PubSub.subscribe(Oli.PubSub, message_grade_update(section_id, resource_access_id, job_id))
  end

  def unsubscribe_to_lms_grade_update(section_id, resource_access_id, job_id) do
    PubSub.unsubscribe(Oli.PubSub, message_grade_update(section_id, resource_access_id, job_id))
  end

  def subscribe_to_lms_grade_update(section_id) do
    PubSub.subscribe(Oli.PubSub, message_grade_update(section_id))
  end

  def unsubscribe_to_lms_grade_update(section_id) do
    PubSub.unsubscribe(Oli.PubSub, message_grade_update(section_id))
  end

  def message_grade_update(section_id, resource_access_id, job_id) do
    "lms_grade_update:#{section_id}:#{resource_access_id}:#{job_id}"
  end

  def message_grade_update(section_id) do
    "lms_grade_update:#{section_id}:*"
  end
end
