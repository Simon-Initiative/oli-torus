defmodule Oli.Utils.CustomDnDResponseMultiSchemaTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.{JSONValidation, SchemaResolver}
  alias Oli.Validation

  @models "test/support/fixtures/custom_dnd_response_multi_models.json"
          |> File.read!()
          |> Jason.decode!()
  @elements "test/support/fixtures/basic_page_elements.json" |> File.read!() |> Jason.decode!()
  @slugs %{"custom-dnd" => "oli_custom_dnd", "response-multi" => "oli_response_multi"}
  defp validate(name, model), do: Validation.validate_activity_schema(@slugs[name], model)
  defp part_path, do: ["authoring", "parts", Access.at(0)]
  defp response_path, do: part_path() ++ ["responses", Access.at(0)]

  test "validates client factories, mixed inputs and grouped parts via cached dispatch" do
    for {name, model} <- @models do
      type =
        case String.starts_with?(name, "custom-dnd") do
          true -> "custom-dnd"
          false -> "response-multi"
        end

      assert :ok = validate(type, model)
    end

    for {name, _slug} <- @slugs do
      root = SchemaResolver.resolve(name <> ".schema.json")
      assert root == SchemaResolver.resolve(name <> ".schema.json")

      for result <- Task.async_stream(1..10, fn _ -> validate(name, @models[name]) end),
          do: assert(result == {:ok, :ok})
    end
  end

  for {name, slug} <- @slugs do
    test "#{name} shares rich content and strict authored wrappers" do
      name = unquote(name)
      model = @models[name]

      slots = [
        ["stem", "content"],
        part_path() ++ ["hints", Access.at(0), "content"],
        part_path() ++ ["explanation", "content"],
        response_path() ++ ["feedback", "content"]
      ]

      case name do
        "response-multi" ->
          model = @models["response-multi-mixed"]
          assert model["choices"] != []
          # Test the choice slot separately because the default factory has no choices.
          for {_label, element} <- @elements do
            assert :ok =
                     validate(
                       name,
                       put_in(model, ["choices", Access.at(0), "content"], [element])
                     )
          end

          assert {:error, [_ | _]} =
                   validate(name, put_in(model, ["choices", Access.at(0), "content"], [%{}]))

          :ok

        _ ->
          :ok
      end

      for path <- slots do
        for {_label, element} <- @elements do
          assert :ok = validate(name, put_in(model, path, [element]))

          assert :ok =
                   validate(
                     name,
                     put_in(model, path, %{"model" => [element], "selection" => nil})
                   )
        end

        for bad <- [
              nil,
              %{},
              [%{}],
              [%{"type" => "unknown"}],
              [
                %{
                  "type" => "table",
                  "children" => [%{"type" => "p", "children" => [%{"text" => "wrong nesting"}]}]
                }
              ]
            ] do
          assert {:error, [_ | _]} = validate(name, put_in(model, path, bad))
        end
      end

      assert {:error, [_ | _]} = validate(name, Map.put(model, "typo", true))

      for path <- [
            ["stem"],
            ["authoring"],
            part_path(),
            part_path() ++ ["hints", Access.at(0)],
            part_path() ++ ["explanation"],
            response_path(),
            response_path() ++ ["feedback"]
          ] do
        assert {:error, [_ | _]} =
                 validate(name, update_in(model, path, &Map.put(&1, "typo", true)))
      end

      for bad <- [nil, [], %{}, Map.delete(model, "stem"), Map.delete(model, "authoring")],
          do: assert({:error, [_ | _]} = validate(name, bad))

      for key <- ~w(parts transformations previewText) do
        assert {:error, [_ | _]} =
                 validate(name, update_in(model, ["authoring"], &Map.delete(&1, key)))
      end

      assert {:error, [_ | _]} = validate(name, put_in(model, ["authoring", "version"], 1))
      root = SchemaResolver.resolve(name <> "-activity.schema.json")

      export = %{
        "id" => "activity",
        "type" => "Activity",
        "subType" => unquote(slug),
        "title" => "Question",
        "content" => model
      }

      assert :ok = JSONValidation.validate(root, export)

      for bad <- [
            Map.put(export, "subType", "oli_multi_input"),
            Map.put(export, "type", "Page"),
            Map.put(export, "typo", true),
            Map.delete(export, "title"),
            Map.put(export, "content", %{})
          ] do
        assert {:error, [_ | _]} = JSONValidation.validate(root, bad)
      end
    end

    test "#{name} retains the opaque math leaf and strict match wrapper" do
      name = unquote(name)
      model = update_in(@models[name], response_path(), &Map.delete(&1, "rule"))
      path = response_path() ++ ["matchConfig"]
      deep = Enum.reduce(1..1000, %{}, fn _, acc -> %{"next" => acc} end)

      for math <- [
            %{},
            deep,
            %{"$ref" => "https://invalid.example/data", "future" => [nil, true]}
          ] do
        assert :ok =
                 validate(
                   name,
                   put_in(model, path, %{
                     "version" => 1,
                     "type" => "math_expression",
                     "math" => math
                   })
                 )
      end

      assert :ok = validate(name, put_in(model, path, %{"version" => 1, "type" => "always"}))

      for bad <- [
            nil,
            %{},
            %{"version" => 2, "type" => "always"},
            %{"version" => 1, "type" => "always", "typo" => true},
            %{"version" => 1, "type" => "math_expression"},
            %{"version" => 1, "type" => "math_expression", "math" => []}
          ] do
        assert {:error, [_ | _]} = validate(name, put_in(model, path, bad))
      end

      assert {:error, [_ | _]} = validate(name, model)
    end
  end

  test "Custom DND requires string dimensions, markup and styles" do
    model = @models["custom-dnd"]

    for field <- ~w(height width layoutStyles targetArea initiators) do
      assert {:error, [_ | _]} = validate("custom-dnd", Map.delete(model, field))

      for bad <- [nil, 400, [], %{}],
          do: assert({:error, [_ | _]} = validate("custom-dnd", Map.put(model, field, bad)))

      assert :ok = validate("custom-dnd", Map.put(model, field, "unparsed string < {"))
    end

    assert :ok =
             validate("custom-dnd", Map.merge(model, %{"height" => "100%", "width" => "auto"}))

    for field <- ~w(inputs choices submitPerPart multInputsPerPart customScoring) do
      assert {:error, [_ | _]} = validate("custom-dnd", Map.put(model, field, []))
    end
  end

  test "Response Multi reuses Multi Input variants, item settings, scoring and strict fields" do
    model = @models["response-multi"]

    for field <- ~w(inputs choices submitPerPart multInputsPerPart) do
      assert {:error, [_ | _]} = validate("response-multi", Map.delete(model, field))
    end

    for field <- ~w(submitPerPart multInputsPerPart customScoring) do
      assert :ok = validate("response-multi", Map.put(model, field, false))
      assert {:error, [_ | _]} = validate("response-multi", Map.put(model, field, "false"))
    end

    input_path = ["inputs", Access.at(0)]

    for type <- ~w(text numeric math math_expression),
        do:
          assert(
            :ok = validate("response-multi", put_in(model, input_path ++ ["inputType"], type))
          )

    for size <- ~w(small medium large 100pct),
        do: assert(:ok = validate("response-multi", put_in(model, input_path ++ ["size"], size)))

    for {key, bad} <- [
          {"inputType", "textarea"},
          {"partId", 1},
          {"id", nil},
          {"size", "huge"},
          {"choiceIds", [1]},
          {"typo", true}
        ] do
      assert {:error, [_ | _]} =
               validate("response-multi", put_in(model, input_path ++ [key], bad))
    end

    dropdown = put_in(model, input_path ++ ["inputType"], "dropdown")
    assert {:error, [_ | _]} = validate("response-multi", dropdown)
    assert :ok = validate("response-multi", put_in(dropdown, input_path ++ ["choiceIds"], []))

    assert :ok =
             validate(
               "response-multi",
               put_in(model, input_path ++ ["choiceIds"], ["old-dropdown-choice"])
             )

    config = %{"version" => 1, "type" => "math_expression", "subtype" => "algebraic"}
    assert :ok = validate("response-multi", put_in(model, input_path ++ ["itemConfig"], config))

    assert {:error, [_ | _]} =
             validate(
               "response-multi",
               put_in(model, input_path ++ ["itemConfig"], Map.put(config, "typo", true))
             )

    for strategy <- ~w(average best most_recent total),
        do: assert(:ok = validate("response-multi", Map.put(model, "scoringStrategy", strategy)))

    assert {:error, [_ | _]} =
             validate("response-multi", Map.put(model, "scoringStrategy", "unknown"))

    assert {:error, [_ | _]} =
             validate(
               "response-multi",
               put_in(model, ["authoring", "targeted"], [["choice", "response"]])
             )
  end

  test "Response Multi contributed responses use its own closed user_name/text shape" do
    model = @models["response-multi"]
    response = %{"user_name" => "Learner", "text" => "Answer"}
    assert :ok = validate("response-multi", put_in(model, ["authoring", "responses"], [response]))

    for bad <- [
          nil,
          %{},
          Map.delete(response, "text"),
          Map.delete(response, "user_name"),
          Map.put(response, "text", 1),
          Map.put(response, "user_name", []),
          Map.put(response, "users", ["Learner"])
        ] do
      assert {:error, [_ | _]} =
               validate("response-multi", put_in(model, ["authoring", "responses"], [bad]))
    end
  end

  test "shared metadata and domain deferrals preserve structural editing states" do
    for {name, _slug} <- @slugs do
      model =
        Map.merge(@models[name], %{
          "resourceId" => 1,
          "id" => "activity",
          "activity_id" => "activity",
          "learningLanguage" => "en",
          "bibrefs" => ["reference"],
          "content" => [nil],
          "activityType" => %{}
        })

      assert :ok = validate(name, model)
      assert {:error, [_ | _]} = validate(name, Map.put(model, "resourceId", "1"))
      assert :ok = validate(name, put_in(model, ["authoring", "parts"], []))

      assert :ok =
               validate(
                 name,
                 put_in(
                   model,
                   ["authoring", "parts"],
                   model["authoring"]["parts"] ++ model["authoring"]["parts"]
                 )
               )

      assert :ok = validate(name, put_in(model, part_path() ++ ["responses"], []))
      assert :ok = validate(name, put_in(model, part_path() ++ ["hints"], []))
    end

    model = @models["response-multi"]
    assert :ok = validate("response-multi", put_in(model, ["inputs"], []))

    assert :ok =
             validate(
               "response-multi",
               put_in(model, ["inputs", Access.at(0), "partId"], "missing-part")
             )

    assert :ok =
             validate(
               "response-multi",
               put_in(model, ["authoring", "targeted"], [
                 [["missing-choice", "missing-choice"], "missing-response"]
               ])
             )
  end
end
