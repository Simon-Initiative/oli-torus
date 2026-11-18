defmodule Oli.Utils.AdaptiveSchemaTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.{JSONValidation, SchemaResolver}
  alias Oli.Validation

  @models "test/support/fixtures/adaptive_models.json" |> File.read!() |> Jason.decode!()
  @elements "test/support/fixtures/basic_page_elements.json" |> File.read!() |> Jason.decode!()
  defp validate(model), do: Validation.validate_activity_schema("oli_adaptive", model)
  defp part_path, do: ["authoring", "parts", Access.at(0)]
  defp rule_path, do: ["authoring", "rules", Access.at(0)]
  defp action_path, do: rule_path() ++ ["event", "params", "actions", Access.at(0)]

  test "validates generic, advanced and flowchart factories with cached concurrent reuse" do
    for {_name, model} <- @models, do: assert(:ok = validate(model))
    root = SchemaResolver.resolve("adaptive.schema.json")
    assert root == SchemaResolver.resolve("adaptive.schema.json")

    for result <- Task.async_stream(1..12, fn _ -> validate(@models["flowchart"]) end),
        do: assert(result == {:ok, :ok})
  end

  test "generic parts reuse Basic Page hints, explanation and response feedback" do
    model = @models["generic"]
    content = get_in(model, part_path() ++ ["explanation"])
    response = %{"id" => "response", "score" => 1, "rule" => "", "feedback" => content}
    model = put_in(model, part_path() ++ ["responses"], [response])

    for path <- [
          part_path() ++ ["hints", Access.at(0), "content"],
          part_path() ++ ["explanation", "content"],
          part_path() ++ ["responses", Access.at(0), "feedback", "content"]
        ] do
      for {_label, element} <- @elements do
        assert :ok = validate(put_in(model, path, [element]))
        assert :ok = validate(put_in(model, path, %{"model" => [element], "selection" => nil}))
      end

      for bad <- [nil, %{}, [%{}], [%{"type" => "unknown"}]],
          do: assert({:error, [_ | _]} = validate(put_in(model, path, bad)))
    end

    path = part_path() ++ ["responses", Access.at(0)]
    model = update_in(model, path, &Map.delete(&1, "rule"))
    deep = Enum.reduce(1..1000, %{}, fn _, acc -> %{"next" => acc} end)

    assert :ok =
             validate(
               put_in(model, path ++ ["matchConfig"], %{
                 "version" => 1,
                 "type" => "math_expression",
                 "math" => deep
               })
             )

    assert {:error, [_ | _]} =
             validate(
               put_in(model, path ++ ["matchConfig"], %{
                 "version" => 1,
                 "type" => "always",
                 "typo" => true
               })
             )
  end

  test "requires authored profiles and closes root, content, part and authoring wrappers" do
    for bad <- [nil, [], %{}, Map.delete(@models["initial"], "authoring")],
        do: assert({:error, [_ | _]} = validate(bad))

    for {name, model} <- @models do
      assert {:error, [_ | _]} = validate(Map.put(model, "typo", true))
      assert {:error, [_ | _]} = validate(put_in(model, ["authoring", "typo"], true))

      assert {:error, [_ | _]} =
               validate(update_in(model, ["authoring"], &Map.delete(&1, "parts")))

      assert {:error, [_ | _]} = validate(put_in(model, part_path() ++ ["typo"], true))
      assert :ok = validate(put_in(model, ["authoring", "parts"], []))

      case name do
        name when name in ["initial", "generic"] ->
          for key <- ~w(previewText transformations),
              do:
                assert(
                  {:error, [_ | _]} =
                    validate(update_in(model, ["authoring"], &Map.delete(&1, key)))
                )

        _ ->
          :ok
      end
    end

    assert {:error, [_ | _]} = validate(put_in(@models["generic"], ["content", "typo"], true))

    for key <- ~w(id type owner inherited),
        do:
          assert(
            {:error, [_ | _]} =
              validate(update_in(@models["advanced"], part_path(), &Map.delete(&1, key)))
          )

    assert {:error, [_ | _]} =
             validate(put_in(@models["advanced"], part_path() ++ ["inherited"], "false"))
  end

  test "layout custom values are opaque records with closed typed component wrappers" do
    model = @models["generic"]
    path = ["content", "partsLayout", Access.at(0)]
    deep = Enum.reduce(1..1000, %{}, fn _, acc -> %{"future" => acc} end)
    assert :ok = validate(put_in(model, path ++ ["custom"], deep))
    assert :ok = validate(put_in(model, path ++ ["type"], "future-plugin"))

    for {key, bad} <- [{"id", 1}, {"type", nil}, {"custom", []}, {"typo", true}],
        do: assert({:error, [_ | _]} = validate(put_in(model, path ++ [key], bad)))

    for key <- ~w(id type custom),
        do: assert({:error, [_ | _]} = validate(update_in(model, path, &Map.delete(&1, key))))

    for key <- ~w(custom content),
        do: assert({:error, [_ | _]} = validate(Map.put(model, key, [])))
  end

  test "rules and recursive conditions are typed without expression or operator semantics" do
    model = @models["advanced"]

    for key <- ~w(id name disabled default correct conditions event),
        do:
          assert(
            {:error, [_ | _]} = validate(update_in(model, rule_path(), &Map.delete(&1, key)))
          )

    condition = %{
      "fact" => "missing.fact",
      "operator" => "futureOperator",
      "value" => %{"arbitraryMath" => [nil, true]}
    }

    model = put_in(model, rule_path() ++ ["conditions"], %{"all" => [%{"any" => [condition]}]})
    assert :ok = validate(model)

    for {key, bad} <- [{"fact", 1}, {"operator", nil}, {"type", "1"}, {"typo", true}],
        do:
          assert(
            {:error, [_ | _]} =
              validate(
                put_in(
                  model,
                  rule_path() ++ ["conditions", "all", Access.at(0), "any", Access.at(0), key],
                  bad
                )
              )
          )

    for bad <- [%{}, [], %{"all" => "conditions"}, %{"all" => [], "typo" => true}],
        do:
          assert({:error, [_ | _]} = validate(put_in(model, rule_path() ++ ["conditions"], bad)))

    for {key, bad} <- [
          {"priority", "1"},
          {"disabled", "true"},
          {"additionalScore", "1"},
          {"typo", true}
        ],
        do: assert({:error, [_ | _]} = validate(put_in(model, rule_path() ++ [key], bad)))
  end

  test "action dispatch validates each params shape and feedback layout wrappers" do
    model = @models["advanced"]

    actions = [
      %{"type" => "navigation", "params" => %{"target" => "missing-screen"}},
      %{
        "type" => "mutateState",
        "params" => %{
          "target" => "state",
          "targetType" => 1,
          "operator" => "=",
          "value" => %{"opaque" => true}
        }
      },
      %{"type" => "activationPoint", "params" => %{"prompt" => "Think", "kind" => "feedback"}},
      %{
        "type" => "feedback",
        "params" => %{"feedback" => %{"custom" => %{}, "partsLayout" => []}}
      }
    ]

    for action <- actions do
      assert :ok = validate(put_in(model, action_path(), action))

      case action["type"] do
        "feedback" ->
          assert :ok =
                   validate(put_in(model, action_path(), Map.put(action, "id", "feedback-id")))

        _ ->
          assert {:error, [_ | _]} =
                   validate(put_in(model, action_path(), Map.put(action, "id", "unexpected-id")))
      end

      assert {:error, [_ | _]} =
               validate(put_in(model, action_path(), put_in(action, ["params", "typo"], true)))

      assert {:error, [_ | _]} =
               validate(put_in(model, action_path(), Map.put(action, "typo", true)))
    end

    for bad <- [
          %{},
          %{"type" => "unknown", "params" => %{}},
          %{"type" => "navigation", "params" => %{}},
          %{"type" => "activationPoint", "params" => %{"prompt" => "X", "kind" => "unknown"}}
        ],
        do: assert({:error, [_ | _]} = validate(put_in(model, action_path(), bad)))
  end

  test "flowchart paths validate required variant fields and forbid fields from other variants" do
    model = @models["flowchart"]
    assert :ok = validate(model)
    path = ["authoring", "flowchart", "paths", Access.at(0)]

    for key <- ~w(componentId destinationScreenId id ruleId completed label priority type),
        do: assert({:error, [_ | _]} = validate(update_in(model, path, &Map.delete(&1, key))))

    assert {:error, [_ | _]} = validate(put_in(model, path ++ ["selectedOption"], 1))
    assert {:error, [_ | _]} = validate(put_in(model, ["authoring", "flowchart", "typo"], true))

    assert {:error, [_ | _]} =
             validate(put_in(model, ["authoring", "variablesRequiredForEvaluation"], [1]))

    base = get_in(model, path)

    for {type, field} <- [
          {"numeric-common-error", "feedbackIndex"},
          {"option-common-error", "selectedOption"},
          {"option-specific", "selectedOption"}
        ] do
      variant = Map.merge(base, %{"type" => type, field => 0})
      assert :ok = validate(put_in(model, path, variant))
      assert {:error, [_ | _]} = validate(put_in(model, path, Map.delete(variant, field)))
    end
  end

  test "factory outcome compatibility is closed and legacy history schema remains separate" do
    model = @models["initial"]
    outcome_path = part_path() ++ ["outcomes", Access.at(0)]
    assert :ok = validate(model)
    assert {:error, [_ | _]} = validate(put_in(model, outcome_path ++ ["typo"], true))

    assert {:error, [_ | _]} =
             validate(put_in(model, outcome_path ++ ["actions", Access.at(0), "update"], []))

    history = SchemaResolver.resolve("adaptive-activity-content.schema.json")

    assert :ok =
             JSONValidation.validate(history, %{
               "partsLayout" => [],
               "authoring" => %{"parts" => [%{"id" => "legacy"}], "rules" => []}
             })
  end

  test "strict export composes the new model and generic Activity envelope" do
    root = SchemaResolver.resolve("adaptive-activity.schema.json")

    for {_name, model} <- @models do
      export = %{
        "id" => "adaptive",
        "type" => "Activity",
        "subType" => "oli_adaptive",
        "title" => "Adaptive",
        "content" => model
      }

      assert :ok = JSONValidation.validate(root, export)

      for bad <- [
            Map.put(export, "subType", "oli_multiple_choice"),
            Map.put(export, "type", "Page"),
            Map.put(export, "typo", true),
            Map.delete(export, "title"),
            Map.put(export, "content", %{})
          ],
          do: assert({:error, [_ | _]} = JSONValidation.validate(root, bad))
    end
  end
end
