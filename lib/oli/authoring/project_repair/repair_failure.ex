defmodule Oli.Authoring.ProjectRepair.RepairFailure do
  @moduledoc """
  Normalizes one failure encountered while preparing or applying a repair.

  Optional page and activity ids keep failures actionable without retaining page
  or activity content. `stage` identifies the failed safety boundary so the web
  layer can display a useful result without decoding arbitrary exceptions.
  """

  @typedoc "The normalized stage at which a repair failed."
  @type stage :: :lock | :stale_plan | :activity_copy | :page_update | :cleanup

  @typedoc """
  A content-free failure code approved to cross the context boundary.

  Internal exceptions and changesets must be normalized to one of these atoms;
  raw terms can contain authored content, SQL details, or account information.
  """
  @type reason ::
          :lock_not_acquired
          | :stale_project_state
          | :activity_copy_failed
          | :page_update_failed
          | :lock_update_failed
          | :invalid_page_content
          | :lock_release_failed
          | :unexpected_error

  @typedoc "A bounded, content-free repair failure."
  @type t :: %__MODULE__{
          stage: stage(),
          reason: reason(),
          page_resource_id: pos_integer() | nil,
          activity_resource_id: pos_integer() | nil
        }

  @enforce_keys [:stage, :reason]
  defstruct [:stage, :reason, :page_resource_id, :activity_resource_id]
end
