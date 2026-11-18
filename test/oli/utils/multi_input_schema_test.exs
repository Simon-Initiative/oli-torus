defmodule Oli.Utils.MultiInputSchemaTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.{JSONValidation, SchemaResolver}
  alias Oli.Validation

  @models "test/support/fixtures/multi_input_models.json" |> File.read!() |> Jason.decode!()
  @elements "test/support/fixtures/basic_page_elements.json" |> File.read!() |> Jason.decode!()

  defp validate(model), do: Validation.validate_activity_schema("oli_multi_input", model)
  defp response_path, do: ["authoring", "parts", Access.at(4), "responses", Access.at(0)]

  test "validates client factories, mixed multipart models and legacy math conversion" do
    for {_name, model} <- @models, do: assert(:ok == validate(model))

    root = SchemaResolver.resolve("multi-input.schema.json")
    assert root == SchemaResolver.resolve("multi-input.schema.json")

    for result <- Task.async_stream(1..12, fn _ -> validate(@models["mixed"]) end),
        do: assert(result == {:ok, :ok})
  end

  test "reuses Basic Page content in stem, choices, hints, feedback and explanation" do
    model = @models["mixed"]

    slots = [
      ["stem", "content"],
      ["choices", Access.at(0), "content"],
      ["authoring", "parts", Access.at(0), "hints", Access.at(0), "content"],
      ["authoring", "parts", Access.at(0), "responses", Access.at(0), "feedback", "content"],
      ["authoring", "parts", Access.at(0), "explanation", "content"]
    ]

    for slot <- slots do
      for {_name, element} <- @elements do
        assert :ok = validate(put_in(model, slot, [element]))
        assert :ok = validate(put_in(model, slot, %{"model" => [element], "selection" => nil}))
      end

      for bad <- [nil, %{}, [%{}], [%{"type" => "unknown"}]] do
        assert {:error, [_ | _]} = validate(put_in(model, slot, bad))
      end
    end
  end

  test "requires structural root fields and closes every authored wrapper" do
    model = @models["mixed"]

    for key <- ["stem", "choices", "inputs", "submitPerPart", "authoring"] do
      assert {:error, [_ | _]} = validate(Map.delete(model, key))
    end

    for path <- [
          [],
          ["stem"],
          ["choices", Access.at(0)],
          ["inputs", Access.at(0)],
          ["authoring"],
          ["authoring", "parts", Access.at(0)],
          ["authoring", "parts", Access.at(0), "hints", Access.at(0)],
          ["authoring", "parts", Access.at(0), "explanation"],
          response_path(),
          response_path() ++ ["feedback"]
        ] do
      bad =
        case path do
          [] -> Map.put(model, "typo", true)
          _ -> update_in(model, path, &Map.put(&1, "typo", true))
        end

      assert {:error, [_ | _]} = validate(bad)
    end

    for bad <- [nil, [], %{}, Map.put(model, "submitPerPart", "true")],
        do: assert({:error, [_ | _]} = validate(bad))
  end

  test "dispatches input variants with typed known fields" do
    model = @models["text"]
    input_path = ["inputs", Access.at(0)]
    input = get_in(model, input_path)

    for type <- ["text", "numeric", "math", "math_expression"] do
      assert :ok = validate(put_in(model, input_path, Map.put(input, "inputType", type)))
    end

    for size <- ["small", "medium", "large", "100pct"] do
      assert :ok = validate(put_in(model, input_path ++ ["size"], size))
    end

    for {field, value} <- [
          {"inputType", "textarea"},
          {"inputType", nil},
          {"id", 1},
          {"partId", 1},
          {"size", "huge"},
          {"size", nil},
          {"choiceIds", [1]},
          {"choiceIds", "choice"},
          {"itemConfig", %{"version" => 1, "type" => "math_expression", "subtype" => "unknown"}}
        ] do
      assert {:error, [_ | _]} = validate(put_in(model, input_path ++ [field], value))
    end

    for key <- ["id", "partId", "inputType"] do
      assert {:error, [_ | _]} = validate(put_in(model, input_path, Map.delete(input, key)))
    end

    dropdown = Map.merge(input, %{"inputType" => "dropdown", "choiceIds" => []})
    assert :ok = validate(put_in(model, input_path, dropdown))

    assert {:error, [_ | _]} =
             validate(put_in(model, input_path, Map.delete(dropdown, "choiceIds")))

    assert {:error, [_ | _]} =
             validate(put_in(model, input_path, Map.put(dropdown, "itemConfig", %{})))

    # Existing editor transitions retain dropdown choiceIds on fill-in inputs.
    assert :ok = validate(put_in(model, input_path, Map.put(input, "choiceIds", ["old-choice"])))
  end

  test "math payload is an opaque leaf, including deeply nested future expression data" do
    model = @models["mixed"]
    math_path = response_path() ++ ["matchConfig", "math"]
    deep = Enum.reduce(1..1000, %{}, fn _, acc -> %{"next" => acc} end)

    for payload <- [
          %{},
          deep,
          %{"$ref" => "https://invalid.example/expression", "future" => [nil, false, 1]}
        ] do
      updated = put_in(model, math_path, payload)
      assert :ok = validate(updated)
      assert :ok = validate(update_in(updated, response_path(), &Map.delete(&1, "rule")))
    end

    for bad <- [nil, [], "expression", 1] do
      assert {:error, [_ | _]} = validate(put_in(model, math_path, bad))
    end
  end

  test "matchConfig wrapper is strict and neither rule nor configuration bypasses validation" do
    model = @models["mixed"]
    path = response_path() ++ ["matchConfig"]

    for bad <- [
          nil,
          %{},
          %{"version" => 2, "type" => "always"},
          %{"version" => 1, "type" => "unknown"},
          %{"version" => 1, "type" => "math_expression"},
          %{"version" => 1, "type" => "always", "math" => %{}},
          %{"version" => 1, "type" => "always", "typo" => true}
        ] do
      assert {:error, [_ | _]} = validate(put_in(model, path, bad))
    end

    assert :ok = validate(put_in(model, path, %{"version" => 1, "type" => "always"}))
    assert {:error, [_ | _]} = validate(put_in(model, response_path() ++ ["rule"], 1))

    assert {:error, [_ | _]} =
             validate(update_in(model, response_path(), &Map.drop(&1, ["rule", "matchConfig"])))
  end

  test "item settings share the Short Answer configuration contract" do
    model = @models["mixed"]
    path = ["inputs", Access.at(4), "itemConfig"]
    assert :ok = validate(model)

    for bad <- [
          nil,
          %{},
          %{"version" => 1, "type" => "math_expression", "subtype" => "algebraic", "typo" => true}
        ] do
      assert {:error, [_ | _]} = validate(put_in(model, path, bad))
    end

    assert {:error, [_ | _]} =
             validate(
               put_in(model, path ++ ["config", "sampling", "includeSpecialPoints"], "true")
             )
  end

  test "scoring, targeting, transformations and contributed responses are typed" do
    model = @models["mixed"]

    response = %{
      "users" => ["learner"],
      "text" => "answer",
      "type" => "text",
      "part_id" => "1",
      "count" => 2
    }

    model = put_in(model, ["authoring", "responses"], [response])
    assert :ok = validate(model)

    for key <- Map.keys(response) do
      assert {:error, [_ | _]} =
               validate(put_in(model, ["authoring", "responses"], [Map.delete(response, key)]))
    end

    for {key, bad} <- [
          {"users", [1]},
          {"text", 1},
          {"type", false},
          {"part_id", 1},
          {"count", "2"},
          {"typo", 1}
        ] do
      assert {:error, [_ | _]} =
               validate(put_in(model, ["authoring", "responses"], [Map.put(response, key, bad)]))
    end

    for strategy <- ["average", "best", "most_recent", "total"] do
      assert :ok =
               validate(
                 Map.merge(model, %{"scoringStrategy" => strategy, "customScoring" => true})
               )
    end

    for {key, bad} <- [{"scoringStrategy", "unknown"}, {"customScoring", 1}],
        do: assert({:error, [_ | _]} = validate(Map.put(model, key, bad)))

    assert {:error, [_ | _]} =
             validate(put_in(model, ["authoring", "targeted"], [["choice", "response"]]))

    assert {:error, [_ | _]} =
             validate(
               put_in(model, ["authoring", "transformations"], [%{"operation" => "unknown"}])
             )
  end

  test "structural validation defers domain integrity and readiness checks" do
    model = @models["mixed"]

    assert :ok =
             validate(
               put_in(model, ["authoring", "targeted"], [
                 [["missing-choice", "missing-choice"], "missing-response"]
               ])
             )

    assert :ok = validate(put_in(model, ["inputs", Access.at(0), "partId"], "missing-part"))
    assert :ok = validate(put_in(model, ["inputs"], model["inputs"] ++ model["inputs"]))
    assert :ok = validate(put_in(model, ["authoring", "parts"], []))
    assert :ok = validate(put_in(model, ["inputs"], []))
  end

  test "export schema enforces exact subtype, envelope and nested model" do
    root = SchemaResolver.resolve("multi-input-activity.schema.json")

    export = %{
      "id" => "activity",
      "type" => "Activity",
      "subType" => "oli_multi_input",
      "title" => "Question",
      "content" => @models["mixed"]
    }

    assert :ok = JSONValidation.validate(root, export)

    for bad <- [
          Map.put(export, "subType", "oli_short_answer"),
          Map.put(export, "typo", true),
          Map.delete(export, "title"),
          put_in(export, ["content", "inputs"], [%{}])
        ] do
      assert {:error, [_ | _]} = JSONValidation.validate(root, bad)
    end
  end
end
