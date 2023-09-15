defmodule Oli.Analytics.Summary.Context do

  @enforce_keys [
    :user_id,
    :host_name,
    :section_id,
    :project_id,
    :publication_id
  ]

  defstruct @enforce_keys

end
