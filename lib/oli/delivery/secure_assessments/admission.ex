defmodule Oli.Delivery.SecureAssessments.Admission do
  @moduledoc """
  Verified server-side entry evidence bound to canonical learner and assessment IDs.
  Construct only in an authenticated entry adapter; never deserialize from client
  parameters. Provider labels are diagnostics, not authorization or browser attestation.
  """
  @enforce_keys [:user_id, :section_id, :resource_id]
  defstruct [:user_id, :section_id, :resource_id, provider: :other]

  @type t :: %__MODULE__{
          user_id: pos_integer(),
          section_id: pos_integer(),
          resource_id: pos_integer(),
          provider: :moodle_seb | :other
        }
end
