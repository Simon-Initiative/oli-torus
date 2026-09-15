defmodule Oli.Scenarios.SectionCopyHooks do
  @moduledoc "Scenario hooks for exercising independent course copies."

  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.{CopyOptions, Enrollment, SectionCopy}
  alias Oli.Repo
  alias Oli.Scenarios.DirectiveTypes.ExecutionState

  @doc "Copies the scenario source course and stores the destination in scenario state."
  @spec copy_source_course(%ExecutionState{}) :: %ExecutionState{}
  def copy_source_course(%ExecutionState{} = state) do
    source = Map.fetch!(state.sections, "source_course")

    {:ok, copy_options} = CopyOptions.for_previous_section(CopyOptions.groups())

    {:ok, copy} =
      SectionCopy.copy(source, %{title: "Copied Course"}, copy_options)

    %{state | sections: Map.put(state.sections, "copied_course", copy)}
  end

  @doc "Verifies that the copied course contains no source enrollments."
  @spec assert_learner_data_was_not_copied(%ExecutionState{}) :: %ExecutionState{}
  def assert_learner_data_was_not_copied(%ExecutionState{} = state) do
    copy = Map.fetch!(state.sections, "copied_course")

    case Repo.aggregate(from(e in Enrollment, where: e.section_id == ^copy.id), :count) do
      0 -> state
      count -> raise "expected no copied learner enrollments, found #{count}"
    end
  end
end

defmodule Oli.Scenarios.SectionCopyTest do
  @moduledoc false

  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @scenario_path Path.join(__DIR__, "section_copy.scenario.yaml")

  test "copies a course snapshot without synchronization or learner data" do
    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())

    assert result.errors == []
    assert Enum.all?(result.verifications, & &1.passed)
  end
end
