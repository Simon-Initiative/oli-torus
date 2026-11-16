defmodule Oli.Utils.MultipleChoiceSchemaTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.{JSONValidation, SchemaResolver}
  alias Oli.Validation

  @model "test/support/fixtures/multiple_choice_model.json" |> File.read!() |> Jason.decode!()
  @elements "test/support/fixtures/basic_page_elements.json" |> File.read!() |> Jason.decode!()
  defp slots,
    do: [
      ["stem", "content"],
      ["choices", Access.at(0), "content"],
      ["authoring", "parts", Access.at(0), "hints", Access.at(0), "content"],
      ["authoring", "parts", Access.at(0), "responses", Access.at(0), "feedback", "content"],
      ["authoring", "parts", Access.at(0), "explanation", "content"]
    ]

  defp validate(model), do: Validation.validate_activity_schema("oli_multiple_choice", model)

  test "accepts actual factory output, legacy V1, and existing exported MCQs" do
    assert :ok = validate(@model)
    legacy = update_in(@model, ["authoring"], &Map.drop(&1, ["version", "targeted"]))
    assert :ok = validate(legacy)

    models =
      Path.wildcard("test/**/*.json")
      |> Enum.flat_map(fn path ->
        case path |> File.read!() |> Jason.decode!() do
          %{"subType" => "oli_multiple_choice", "content" => model} -> [{path, model}]
          _ -> []
        end
      end)

    assert length(models) >= 7
    export_root = SchemaResolver.resolve("multiple-choice-activity.schema.json")

    for {path, model} <- models do
      assert :ok == validate(model)
      assert :ok == JSONValidation.validate(export_root, path |> File.read!() |> Jason.decode!())
    end
  end

  test "composes the existing Activity export envelope with the MCQ model" do
    root = SchemaResolver.resolve("multiple-choice-activity.schema.json")

    exported = %{
      "id" => "activity",
      "type" => "Activity",
      "subType" => "oli_multiple_choice",
      "content" => @model,
      "title" => "Question"
    }

    assert :ok = JSONValidation.validate(root, exported)

    assert {:error, [_ | _]} =
             JSONValidation.validate(
               root,
               Map.put(exported, "subType", "oli_check_all_that_apply")
             )

    assert {:error, [_ | _]} = JSONValidation.validate(root, Map.delete(exported, "title"))

    assert {:error, [_ | _]} =
             JSONValidation.validate(root, put_in(exported, ["content", "stem"], false))
  end

  test "all five content slots reuse every Basic Page factory example" do
    for {_name, element} <- @elements, slot <- slots() do
      assert :ok = validate(put_in(@model, slot, [element]))
    end
  end

  test "page and both activity content representations use the same rich-text array definition" do
    page_ref = SchemaResolver.get("content-block.schema.json").schema["properties"]["children"]

    activity = SchemaResolver.get("activity-components.schema.json").schema["$defs"]["rich-text"]
    assert page_ref == activity["then"]
    assert page_ref == activity["else"]["properties"]["model"]

    assert page_ref == %{
             "$ref" =>
               "http://torus.oli.cmu.edu/schemas/v0-1-0/content-element.schema.json#/$defs/rich-text"
           }
  end

  test "recursive malformed content is rejected in every slot with a usable location" do
    bad = %{
      "type" => "table",
      "children" => [
        %{
          "type" => "tr",
          "children" => [%{"type" => "td", "children" => [%{"type" => "p", "children" => [%{}]}]}]
        }
      ]
    }

    prefixes = [
      "#/stem/content",
      "#/choices/0/content",
      "#/authoring/parts/0/hints/0/content",
      "#/authoring/parts/0/responses/0/feedback/content",
      "#/authoring/parts/0/explanation/content"
    ]

    for {slot, prefix} <- Enum.zip(slots(), prefixes) do
      assert {:error, errors} = validate(put_in(@model, slot, [bad]))

      assert {:error, [_ | _]} =
               validate(put_in(@model, slot, %{"model" => [bad], "selection" => nil}))

      assert Enum.any?(errors, fn {message, path} ->
               is_binary(message) and String.starts_with?(path, prefix)
             end)
    end
  end

  test "rejects non-arrays, unknown elements, and malformed media in every content slot" do
    for slot <- slots(),
        content <- [
          nil,
          %{"model" => false},
          [%{}],
          [%{"type" => "unknown", "text" => "bypass"}],
          [%{"type" => "video", "src" => [%{"url" => false}]}]
        ] do
      assert {:error, [_ | _]} = validate(put_in(@model, slot, content))
    end
  end

  test "validates MCQ structure without imposing publish-readiness rules" do
    for bad <- [
          nil,
          [],
          %{},
          Map.delete(@model, "stem"),
          Map.put(@model, "choices", []),
          put_in(@model, ["authoring", "parts"], []),
          put_in(@model, ["authoring", "parts"], [
            hd(@model["authoring"]["parts"]),
            hd(@model["authoring"]["parts"])
          ]),
          put_in(@model, ["authoring", "version"], 3),
          update_in(@model, ["authoring"], &Map.delete(&1, "targeted")),
          put_in(
            @model,
            ["authoring", "parts", Access.at(0), "responses", Access.at(0), "score"],
            "1"
          )
        ] do
      assert {:error, [_ | _]} = validate(bad)
    end

    # Existing editing states permit a single choice and no hints/explanation.
    draft =
      @model
      |> Map.update!("choices", &Enum.take(&1, 1))
      |> put_in(["authoring", "parts", Access.at(0), "hints"], [])
      |> put_in(["authoring", "parts", Access.at(0), "explanation"], nil)

    assert :ok = validate(draft)
  end

  test "supports targeted feedback, scoring, activity triggers and dynamic variables" do
    response = @model["authoring"]["parts"] |> hd() |> Map.fetch!("responses") |> hd()

    model =
      @model
      |> put_in(["authoring", "targeted"], [[[hd(@model["choices"])["id"]], response["id"]]])
      |> put_in(["authoring", "parts", Access.at(0), "triggers"], [
        %{
          "id" => "hint-trigger",
          "type" => "trigger",
          "trigger_type" => "hint",
          "prompt" => "Help",
          "ref_id" => 1
        },
        %{
          "id" => "targeted-trigger",
          "type" => "trigger",
          "trigger_type" => "targeted_feedback",
          "prompt" => "Help",
          "ref_id" => response["id"]
        }
      ])
      |> update_in(
        ["authoring", "transformations"],
        &(&1 ++
            [
              %{
                "operation" => "variable_substitution",
                "data" => [%{"variable" => "x", "expression" => "1 + 2"}]
              }
            ])
      )

    assert :ok = validate(model)

    for targeted <- [[[]], [[["choice"], "response", "extra"]], [[[1], "response"]]] do
      assert {:error, [_ | _]} = validate(put_in(model, ["authoring", "targeted"], targeted))
    end

    assert {:error, [_ | _]} =
             validate(
               put_in(
                 model,
                 ["authoring", "parts", Access.at(0), "triggers", Access.at(0), "ref_id"],
                 "1"
               )
             )

    assert {:error, [_ | _]} =
             validate(
               put_in(model, ["authoring", "transformations"], [%{"operation" => "shuffle"}])
             )

    assert {:error, [_ | _]} =
             validate(
               put_in(model, ["authoring", "transformations"], [
                 %{"operation" => "variable_substitution", "data" => [%{}]}
               ])
             )
  end

  test "keeps domain semantics separate and does not guess activity types" do
    # JSON Schema cannot compare IDs in different arrays or parse the response rule language.
    model =
      put_in(@model, ["authoring", "targeted"], [[["nonexistent-choice"], "nonexistent-response"]])

    assert :ok = validate(model)

    assert {:error, message} =
             Validation.validate_activity_schema("oli_unsupported_test_activity", @model)

    assert is_binary(message)
    assert {:ok, _} = Validation.validate_activity(%{"authoring" => %{"parts" => []}})
  end

  test "rejects unknown fields on the MCQ and every structured activity component" do
    paths = [
      ["authoring"],
      ["stem"],
      ["choices", Access.at(0)],
      ["authoring", "parts", Access.at(0)],
      ["authoring", "parts", Access.at(0), "hints", Access.at(0)],
      ["authoring", "parts", Access.at(0), "responses", Access.at(0)],
      ["authoring", "parts", Access.at(0), "responses", Access.at(0), "feedback"],
      ["authoring", "parts", Access.at(0), "explanation"],
      ["authoring", "transformations", Access.at(0)]
    ]

    assert {:error, [_ | _]} = validate(Map.put(@model, "explanaton", %{"content" => []}))

    for path <- paths do
      assert {:error, [_ | _]} =
               validate(update_in(@model, path, &Map.put(&1, "explanaton", %{"content" => []})))
    end

    # Frequency is a choice extension, not a field on stem/hint/feedback wrappers.
    assert :ok = validate(put_in(@model, ["choices", Access.at(0), "frequency"], 2))
    assert {:error, [_ | _]} = validate(put_in(@model, ["stem", "frequency"], 2))

    variable = %{
      "operation" => "variable_substitution",
      "data" => [%{"variable" => "x", "expression" => "1"}]
    }

    model = put_in(@model, ["authoring", "transformations"], [variable])

    assert {:error, [_ | _]} =
             validate(
               put_in(
                 model,
                 [
                   "authoring",
                   "transformations",
                   Access.at(0),
                   "data",
                   Access.at(0),
                   "expresion"
                 ],
                 "bad"
               )
             )

    trigger = %{
      "id" => "trigger",
      "type" => "trigger",
      "trigger_type" => "explanation",
      "prompt" => "help",
      "promt" => "typo"
    }

    assert {:error, [_ | _]} =
             validate(put_in(@model, ["authoring", "parts", Access.at(0), "triggers"], [trigger]))
  end

  test "legacy editor selection is explicit and rejects unknown fields recursively" do
    point = %{"path" => [0, 0], "offset" => 0}
    selection = %{"anchor" => point, "focus" => point}
    legacy = %{"model" => @model["stem"]["content"], "selection" => selection}
    model = put_in(@model, ["stem", "content"], legacy)
    assert :ok = validate(model)
    assert :ok = validate(put_in(model, ["stem", "content", "selection"], nil))
    assert {:error, [_ | _]} = validate(put_in(model, ["stem", "content", "seletion"], selection))

    assert {:error, [_ | _]} =
             validate(put_in(model, ["stem", "content", "selection", "anchro"], point))

    assert {:error, [_ | _]} =
             validate(put_in(model, ["stem", "content", "selection", "anchor", "offest"], 1))
  end

  test "export closure admits the generic envelope fields but rejects misspellings" do
    schema = SchemaResolver.get("multiple-choice-activity.schema.json").schema
    generic = SchemaResolver.get("activity.schema.json").schema
    assert Enum.sort(Map.keys(schema["properties"])) == Enum.sort(Map.keys(generic["properties"]))
    root = SchemaResolver.resolve("multiple-choice-activity.schema.json")

    exported = %{
      "id" => "activity",
      "type" => "Activity",
      "subType" => "oli_multiple_choice",
      "content" => @model,
      "title" => "Question",
      "tags" => [],
      "objectives" => %{},
      "unresolvedReferences" => []
    }

    assert :ok = JSONValidation.validate(root, exported)
    assert {:error, [_ | _]} = JSONValidation.validate(root, Map.put(exported, "titel", "typo"))
  end

  test "shared rich-content extension compatibility is unchanged" do
    assert :ok =
             validate(
               put_in(@model, ["stem", "content", Access.at(0), "customMetadata"], %{
                 "legacy" => true
               })
             )
  end

  test "repeated and concurrent named resolution reuses the same built schema" do
    root = SchemaResolver.resolve("multiple-choice.schema.json")

    for result <-
          Task.async_stream(1..20, fn _ ->
            resolved = SchemaResolver.resolve("multiple-choice.schema.json")
            {resolved == root, JSONValidation.validate(resolved, @model)}
          end) do
      assert {:ok, {true, :ok}} == result
    end
  end
end
