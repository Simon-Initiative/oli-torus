defmodule Oli.Auditing.EventReferenceTest do
  use ExUnit.Case, async: true

  alias Oli.Auditing.{EventCatalog, EventReference}

  test "the committed reference matches the catalog and examples" do
    assert File.read!(EventReference.path()) == EventReference.render(),
           "#{EventReference.path()} is stale; regenerate it with " <>
             "MIX_ENV=test mix run test/support/audit_log_event_reference.exs"
  end

  test "documents every event" do
    rendered = EventReference.render()

    for name <- EventCatalog.names() do
      assert rendered =~ "### `#{name}`"
    end
  end
end
