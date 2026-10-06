defmodule Oli.Scenarios.RunAllTest do
  use Oli.Scenarios.ScenarioRunner

  @moduletag isolation: "serializable"
  setup :setup_tags
end
