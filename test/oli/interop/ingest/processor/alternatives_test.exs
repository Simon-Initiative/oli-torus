defmodule Oli.Interop.Ingest.Processor.AlternativesTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Oli.Interop.Ingest.Processor.Alternatives
  alias Oli.Interop.Ingest.State

  test "defaults strategy-less legacy groups to learner preference" do
    revision = Alternatives.mapper(%State{slug_prefix: "import"}, 42, group(%{}))

    assert revision.content["strategy"] == "user_section_preference"
  end

  test "canonicalizes the legacy experiment strategy and preserves stable options" do
    options = [%{"id" => "control", "name" => "Control"}]

    revision =
      Alternatives.mapper(
        %State{slug_prefix: "import"},
        42,
        group(%{"strategy" => "upgrade_decision_point", "options" => options})
      )

    assert revision.content == %{
             "strategy" => "experiment_controlled",
             "options" => options
           }
  end

  test "preserves unsupported strategies so validation can reject them explicitly" do
    {revision, log} =
      with_log(fn ->
        Alternatives.mapper(
          %State{slug_prefix: "import"},
          42,
          group(%{"strategy" => "unsupported"})
        )
      end)

    assert revision.content["strategy"] == "unsupported"
    assert log =~ "Unsupported Alternatives strategy encountered during ingest"
    assert log =~ ~s("unsupported")
  end

  defp group(content), do: %{"title" => "Group", "content" => content}
end
