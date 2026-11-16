defmodule Oli.Utils.UploadShortAnswerSchemaTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.{JSONValidation, SchemaResolver}
  alias Oli.Validation

  @models "test/support/fixtures/upload_short_answer_models.json"
          |> File.read!()
          |> Jason.decode!()
  @elements "test/support/fixtures/basic_page_elements.json" |> File.read!() |> Jason.decode!()
  @slugs %{"file-upload" => "oli_file_upload", "short-answer" => "oli_short_answer"}

  defp validate(name, model), do: Validation.validate_activity_schema(@slugs[name], model)

  defp slots do
    [
      ["stem", "content"],
      ["authoring", "parts", Access.at(0), "hints", Access.at(0), "content"],
      ["authoring", "parts", Access.at(0), "responses", Access.at(0), "feedback", "content"],
      ["authoring", "parts", Access.at(0), "explanation", "content"]
    ]
  end

  defp response_path, do: ["authoring", "parts", Access.at(0), "responses", Access.at(0)]
  defp math_path, do: response_path() ++ ["matchConfig", "math"]

  for {name, slug} <- @slugs do
    test "#{name} validates factory output, shared content, strict fields, and export dispatch" do
      name = unquote(name)
      model = @models[name]
      assert :ok = validate(name, model)

      for {_label, element} <- @elements, slot <- slots() do
        assert :ok = validate(name, put_in(model, slot, [element]))

        assert :ok =
                 validate(name, put_in(model, slot, %{"model" => [element], "selection" => nil}))
      end

      for slot <- slots(),
          bad <- [
            nil,
            %{},
            [%{}],
            [%{"type" => "unknown"}],
            [
              %{
                "type" => "table",
                "children" => [%{"type" => "p", "children" => [%{"text" => "bad nesting"}]}]
              }
            ]
          ] do
        assert {:error, [_ | _]} = validate(name, put_in(model, slot, bad))
      end

      assert {:error, [_ | _]} = validate(name, Map.put(model, "explanaton", %{}))

      for path <- [
            ["authoring"],
            ["stem"],
            ["authoring", "parts", Access.at(0)],
            response_path(),
            response_path() ++ ["feedback"],
            ["authoring", "parts", Access.at(0), "hints", Access.at(0)],
            ["authoring", "parts", Access.at(0), "explanation"]
          ] do
        assert {:error, [_ | _]} =
                 validate(name, update_in(model, path, &Map.put(&1, "explanaton", %{})))
      end

      for bad <- [
            nil,
            [],
            %{},
            Map.delete(model, "stem"),
            put_in(model, ["authoring", "parts"], []),
            put_in(
              model,
              ["authoring", "parts"],
              model["authoring"]["parts"] ++ model["authoring"]["parts"]
            )
          ] do
        assert {:error, [_ | _]} = validate(name, bad)
      end

      # Empty response lists are structurally valid manual/editing states; readiness is deferred.
      assert :ok =
               validate(
                 name,
                 put_in(model, ["authoring", "parts", Access.at(0), "responses"], [])
               )

      root = SchemaResolver.resolve(name <> "-activity.schema.json")

      export = %{
        "id" => "activity",
        "type" => "Activity",
        "subType" => unquote(slug),
        "title" => "Question",
        "content" => model
      }

      assert :ok = JSONValidation.validate(root, export)

      assert {:error, [_ | _]} =
               JSONValidation.validate(root, Map.put(export, "subType", "oli_multiple_choice"))

      assert {:error, [_ | _]} = JSONValidation.validate(root, Map.put(export, "titel", "typo"))
      assert {:error, [_ | _]} = JSONValidation.validate(root, Map.delete(export, "title"))

      for result <- Task.async_stream(1..10, fn _ -> validate(name, model) end),
          do: assert(result == {:ok, :ok})
    end
  end

  test "FileSpec follows declared TypeScript fields without enforcing upload policy" do
    model = @models["file-upload"]

    assert :ok =
             validate(
               "file-upload",
               update_in(model, ["fileSpec"], &Map.delete(&1, "maxSizeInBytes"))
             )

    assert :ok = validate("file-upload", put_in(model, ["fileSpec", "maxCount"], -0.5))

    for key <- ["accept", "maxCount"] do
      assert {:error, [_ | _]} =
               validate("file-upload", update_in(model, ["fileSpec"], &Map.delete(&1, key)))
    end

    for {key, value} <- [
          {"accept", []},
          {"maxCount", "1"},
          {"maxSizeInBytes", "1024"},
          {"maxCout", 1}
        ] do
      assert {:error, [_ | _]} = validate("file-upload", put_in(model, ["fileSpec", key], value))
    end
  end

  test "all Short Answer input variants and student response examples are typed" do
    model = @models["short-answer"]

    for kind <- ["text", "numeric", "textarea", "math", "math_expression", "vlabvalue"] do
      assert :ok = validate("short-answer", Map.put(model, "inputType", kind))
    end

    assert :ok =
             validate(
               "short-answer",
               Map.merge(model, %{
                 "submitAndCompare" => true,
                 "responses" => [%{"users" => ["user"], "text" => "example"}]
               })
             )

    for {field, bad} <- [
          {"inputType", "unknown"},
          {"inputType", nil},
          {"submitAndCompare", "true"},
          {"responses", [%{"users" => [1], "text" => "example"}]},
          {"responses", [%{"users" => [], "text" => "example", "typo" => true}]}
        ] do
      assert {:error, [_ | _]} = validate("short-answer", Map.put(model, field, bad))
    end

    assert {:error, [_ | _]} = validate("short-answer", Map.delete(model, "inputType"))
    assert {:error, [_ | _]} = validate("short-answer", @models["file-upload"])
    assert {:error, [_ | _]} = validate("file-upload", model)
  end

  test "math JSON is an opaque object leaf including unknown and deeply nested representations" do
    model = @models["math-expression"]
    assert :ok = validate("short-answer", model)
    deep = Enum.reduce(1..1000, %{"newNode" => true}, fn _, child -> %{"node" => child} end)

    for payload <- [
          %{},
          %{
            "$ref" => "https://example.invalid/not-a-schema",
            "unexpected" => [nil, false, %{"unknown" => true}]
          },
          %{"mode" => "future-mode", "expected" => %{"arbitraryAST" => [1, "x"]}},
          deep
        ] do
      changed = put_in(model, math_path(), payload)
      assert :ok = validate("short-answer", changed)
      # Structured responses may omit the legacy rule entirely.
      assert :ok =
               validate(
                 "short-answer",
                 update_in(changed, response_path(), &Map.delete(&1, "rule"))
               )
    end

    for bad <- [nil, [], "expression", 1] do
      assert {:error, [_ | _]} = validate("short-answer", put_in(model, math_path(), bad))
    end
  end

  test "matchConfig wrappers stay strict and neither legacy rules nor matchConfig bypass invalid fields" do
    model = @models["math-expression"]
    path = response_path() ++ ["matchConfig"]

    for bad <- [
          nil,
          %{},
          %{"version" => 2, "type" => "always"},
          %{"version" => 1, "type" => "math_expression"},
          %{"version" => 1, "type" => "always", "math" => %{}},
          %{"version" => 1, "type" => "always", "typo" => true}
        ] do
      assert {:error, [_ | _]} = validate("short-answer", put_in(model, path, bad))
    end

    assert {:error, [_ | _]} =
             validate(
               "short-answer",
               update_in(model, response_path(), &Map.drop(&1, ["rule", "matchConfig"]))
             )

    assert {:error, [_ | _]} =
             validate("short-answer", put_in(model, response_path() ++ ["rule"], 1))

    assert :ok =
             validate(
               "file-upload",
               put_in(@models["file-upload"], path, %{"version" => 1, "type" => "always"})
             )
  end

  test "item configuration checks settings separately without a schema for math expressions" do
    model = @models["math-expression"]

    for subtype <- [
          "numeric",
          "algebraic",
          "number_with_units",
          "expression_with_units",
          "integer",
          "decimal",
          "fraction",
          "simplified_fraction",
          "latex_direct"
        ] do
      assert :ok = validate("short-answer", put_in(model, ["itemConfig", "subtype"], subtype))
    end

    for {field, bad} <- [
          {"version", 2},
          {"type", "unknown"},
          {"subtype", "unknown"},
          {"subtyp", "algebraic"}
        ] do
      assert {:error, [_ | _]} =
               validate("short-answer", put_in(model, ["itemConfig", field], bad))
    end

    for policy <- [
          %{"type" => "ignored"},
          %{"type" => "strict_unit", "unit" => "m"},
          %{"type" => "accepted_units", "units" => []},
          %{"type" => "convertible_units", "units" => ["not-evaluated"]}
        ] do
      assert :ok =
               validate(
                 "short-answer",
                 put_in(model, ["itemConfig", "config", "unitPolicy"], policy)
               )
    end

    for policy <- [
          %{"type" => "strict_unit"},
          %{"type" => "ignored", "units" => []},
          %{"type" => "accepted_units", "units" => [1]}
        ] do
      assert {:error, [_ | _]} =
               validate(
                 "short-answer",
                 put_in(model, ["itemConfig", "config", "unitPolicy"], policy)
               )
    end

    assert {:error, [_ | _]} =
             validate(
               "short-answer",
               put_in(model, ["itemConfig", "config", "sampling", "includeSpecialPoints"], "true")
             )

    assert {:error, [_ | _]} =
             validate(
               "short-answer",
               put_in(
                 model,
                 [
                   "itemConfig",
                   "config",
                   "validation",
                   "domains",
                   Access.at(0),
                   "lower",
                   "value"
                 ],
                 "1"
               )
             )

    assert {:error, [_ | _]} =
             validate(
               "short-answer",
               put_in(model, ["itemConfig", "config", "numeric"], %{"integerOnyl" => true})
             )
  end

  test "legacy Short Answer exports remain valid" do
    root = SchemaResolver.resolve("short-answer-activity.schema.json")

    for path <- ["test/oli/interop/digest/1075.json", "test/oli/interop/digest/44.json"] do
      export = path |> File.read!() |> Jason.decode!()
      assert :ok = validate("short-answer", export["content"])
      assert :ok = JSONValidation.validate(root, export)
    end
  end
end
