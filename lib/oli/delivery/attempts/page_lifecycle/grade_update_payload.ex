defmodule Oli.Delivery.Attempts.PageLifecycle.GradeUpdatePayload do
  @enforce_keys [:resource_access_id, :job, :status, :details]

  defstruct [:resource_access_id, :job, :status, :details]
end
