defmodule OliWeb.Admin.IngestV2Test do
  use ExUnit.Case, async: true

  alias Oli.Interop.Ingest.State
  alias OliWeb.Admin.IngestV2

  test "normalizes controlled Processor rollback state to a render-safe message" do
    message =
      "Resource [activity-1.json] has invalid learningModelParameters: unsupported schema"

    error_state = %State{errors: [message]}

    assert IngestV2.process_error(error_state) == message
    assert IngestV2.process_error(:unexpected) == "An error occurred while processing the archive"
  end
end
