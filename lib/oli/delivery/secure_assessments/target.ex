defmodule Oli.Delivery.SecureAssessments.Target do
  @moduledoc "Canonical assessment identity resolved from persisted records, never client claims."

  @enforce_keys [:section_id, :resource_id, :secure_delivery]
  defstruct [
    :section_id,
    :resource_id,
    :secure_delivery,
    :user_id,
    :revision_id,
    :activity_revision_id,
    :activity_resource_id,
    :resource_attempt_guid,
    :activity_attempt_guid,
    :part_attempt_guid,
    :lifecycle_state
  ]
end
