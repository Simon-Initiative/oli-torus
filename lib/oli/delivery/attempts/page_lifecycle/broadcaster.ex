defmodule Oli.Delivery.Attempts.PageLifecycle.Broadcaster do
  alias Phoenix.PubSub

  alias Oli.Delivery.Attempts.PageLifecycle.GradeUpdatePayload

  def broadcast_lms_grade_update(section_id, resource_access_id, job, status, details) do
    PubSub.broadcast(
      Oli.PubSub,
      message_grade_update(section_id, resource_access_id),
      {:lms_grade_update_result,
       %GradeUpdatePayload{
         resource_access_id: resource_access_id,
         job: job,
         status: status,
         details: details
       }}
    )

    PubSub.broadcast(
      Oli.PubSub,
      message_grade_update(section_id),
      {:lms_grade_update_result,
       %GradeUpdatePayload{
         resource_access_id: resource_access_id,
         job: job,
         status: status,
         details: details
       }}
    )
  end

  def broadcast_attempt_updated(resource_attempt_guid, activity_attempt_guid, change_type) do
    # We only broadcast these messages when the live debugging aspect of the attempt debugger
    # is enabled
    if Oli.Features.enabled?("live-debugging") do
      PubSub.broadcast(
        Oli.PubSub,
        message_attempt(resource_attempt_guid),
        {change_type,activity_attempt_guid}
      )
    end
  end

  def subscribe_to_lms_grade_update(section_id, resource_access_id, _) do
    PubSub.subscribe(Oli.PubSub, message_grade_update(section_id, resource_access_id))
  end

  def unsubscribe_to_lms_grade_update(section_id, resource_access_id, _) do
    PubSub.unsubscribe(Oli.PubSub, message_grade_update(section_id, resource_access_id))
  end

  def subscribe_to_lms_grade_update(section_id) do
    PubSub.subscribe(Oli.PubSub, message_grade_update(section_id))
  end

  def subscribe_to_attempt(resource_attempt_guid) do
    PubSub.subscribe(Oli.PubSub, message_attempt(resource_attempt_guid))
  end


  def unsubscribe_to_lms_grade_update(section_id) do
    PubSub.unsubscribe(Oli.PubSub, message_grade_update(section_id))
  end

  def message_grade_update(section_id, resource_access_id) do
    "lms_grade_update_#{section_id}:#{resource_access_id}"
  end

  def message_grade_update(section_id) do
    "lms_grade_update_#{section_id}:*"
  end

  def message_attempt(resource_attempt_guid) do
    "attempt_updated_#{resource_attempt_guid}:*"
  end

end
