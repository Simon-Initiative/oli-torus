defmodule Oli.Delivery.Experiments.PageDecisionsTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Experiments.PageDecisions
  alias Oli.Resources.Alternatives

  test "returns empty decisions when no resource attempt exists" do
    assert PageDecisions.prepare(%{}, %{resource_attempts: []}) == %{
             alternative_groups_by_id: %{},
             experiment_decisions: %{},
             experiment_attributions: []
           }
  end

  test "builds inert fallback decisions independently for repeated placements" do
    content = %{
      "model" => [
        %{"type" => "alternatives", "id" => "first", "alternatives_id" => 10, "children" => []},
        %{"type" => "alternatives", "id" => "second", "alternatives_id" => 10, "children" => []}
      ]
    }

    assert {%{"first" => %{status: :no_experiment}, "second" => %{status: :no_experiment}}, []} =
             Alternatives.fallback_delivery_decisions(content)
  end

  test "prepares fallback decisions for Alternatives inside ordinary containers" do
    content = %{
      "model" => [
        %{
          "type" => "group",
          "children" => [
            %{
              "type" => "alternatives",
              "id" => "nested",
              "alternatives_id" => 10,
              "children" => []
            }
          ]
        }
      ]
    }

    assert Alternatives.fallback_delivery_decisions(content) ==
             {%{"nested" => %{status: :no_experiment}}, []}
  end

  test "stops discovery at an Alternatives boundary" do
    inner = %{
      "type" => "alternatives",
      "id" => "inner",
      "alternatives_id" => 20,
      "children" => []
    }

    content = %{
      "model" => [
        %{
          "type" => "alternatives",
          "id" => "outer",
          "alternatives_id" => 10,
          "children" => [
            %{"type" => "alternative", "value" => "a", "children" => [inner]}
          ]
        }
      ]
    }

    assert Alternatives.fallback_delivery_decisions(content) ==
             {%{"outer" => %{status: :no_experiment}}, []}
  end
end
