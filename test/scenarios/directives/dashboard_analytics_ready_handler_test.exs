defmodule Oli.Scenarios.Directives.DashboardAnalyticsReadyHandlerTest do
  use ExUnit.Case, async: true

  alias Oli.Scenarios.DirectiveTypes.{DashboardAnalyticsReadyDirective, ExecutionState}
  alias Oli.Scenarios.Directives.DashboardAnalyticsReadyHandler

  test "succeeds for a known section without waiting on wall-clock time" do
    state = %ExecutionState{
      sections: %{"demo_section" => %{slug: "demo-section"}}
    }

    directive = %DashboardAnalyticsReadyDirective{section: "demo_section"}

    assert {:ok, ^state} = DashboardAnalyticsReadyHandler.handle(directive, state)
  end

  test "fails when the section is unknown" do
    state = %ExecutionState{}
    directive = %DashboardAnalyticsReadyDirective{section: "missing_section"}

    assert {:error, message} = DashboardAnalyticsReadyHandler.handle(directive, state)
    assert message =~ "Section 'missing_section' not found"
  end
end
