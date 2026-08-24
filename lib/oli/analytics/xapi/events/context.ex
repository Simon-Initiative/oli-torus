defmodule Oli.Analytics.XAPI.Events.Context do
  @enforce_keys [
    :user_id,
    :host_name,
    :section_id,
    :project_id,
    :publication_id
  ]

  @optional_fields [:enrollment_id]

  defstruct @enforce_keys ++ @optional_fields
end
