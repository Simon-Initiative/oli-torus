defmodule Oli.Delivery.SecureAssessments.Scope do
  @moduledoc "Provider-neutral immutable scope belonging to one authentication token."
  @enforce_keys [:section_id, :resource_id]
  defstruct [:section_id, :resource_id]

  @type t :: %__MODULE__{section_id: pos_integer(), resource_id: pos_integer()}
end
