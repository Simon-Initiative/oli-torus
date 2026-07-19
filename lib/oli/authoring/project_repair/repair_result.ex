defmodule Oli.Authoring.ProjectRepair.RepairResult do
  @moduledoc """
  Captures the actual state before and after an explicit repair invocation.

  Partial completion is a supported, retryable outcome. Carrying both reports and
  committed counts makes that state explicit and prevents callers from inferring
  success from a flash message or an exception alone.
  """

  alias Oli.Authoring.ProjectRepair.{RepairFailure, Report}

  @typedoc "The completion state of a repair invocation."
  @type status :: :completed | :partial | :failed

  @typedoc "A non-fatal, content-free condition surfaced after repair cleanup."
  @type warning :: :lock_release_failed | :lock_refresh_failed

  @typedoc "A structured repair outcome suitable for rendering and verification."
  @type t :: %__MODULE__{
          status: status(),
          report_before_repair: Report.t(),
          report_after_repair: Report.t(),
          cloned_activity_count: non_neg_integer(),
          updated_page_count: non_neg_integer(),
          failures: [RepairFailure.t()],
          warnings: [warning()]
        }

  @enforce_keys [:status, :report_before_repair, :report_after_repair]
  defstruct status: nil,
            report_before_repair: nil,
            report_after_repair: nil,
            cloned_activity_count: 0,
            updated_page_count: 0,
            failures: [],
            warnings: []
end
