defmodule Oli.InstructorDashboard.OracleMigrationTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.OracleRegistry
  alias Oli.InstructorDashboard.Oracles.SectionAnalytics

  @covered_paths [
    "lib/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live.ex",
    "lib/oli_web/components/delivery/instructor_dashboard/section_analytics.ex"
  ]

  describe "no-bypass guardrails for covered instructor dashboard consumers" do
    # @ac "AC-005"
    test "covered modules do not call ClickHouse analytics directly" do
      Enum.each(@covered_paths, fn path ->
        contents = File.read!(path)

        refute String.contains?(contents, "Oli.Analytics.ClickhouseAnalytics"),
               "#{path} bypasses instructor dashboard oracle path"
      end)
    end

    test "covered modules reference the instructor section analytics oracle boundary" do
      Enum.each(@covered_paths, fn path ->
        contents = File.read!(path)

        assert String.contains?(contents, "Oli.InstructorDashboard.Oracles.SectionAnalytics"),
               "#{path} is expected to use instructor section analytics oracle boundary"
      end)
    end
  end

  describe "registry migration path" do
    test "instructor registry resolves analytics consumer through oracle bindings" do
      assert {:ok, %{required: [:oracle_instructor_section_analytics], optional: []}} =
               OracleRegistry.dependencies_for(:legacy_section_analytics)

      assert {:ok, SectionAnalytics} =
               OracleRegistry.oracle_module(:oracle_instructor_section_analytics)
    end
  end
end
