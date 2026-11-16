defmodule Oli.Utils.ChoiceFamilySchemaTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.{JSONValidation, SchemaResolver}
  alias Oli.Validation

  @models "test/support/fixtures/choice_family_models.json" |> File.read!() |> Jason.decode!()
  @elements "test/support/fixtures/basic_page_elements.json" |> File.read!() |> Jason.decode!()
  @slugs %{
    "ordering" => "oli_ordering",
    "check-all-that-apply" => "oli_check_all_that_apply",
    "likert" => "oli_likert"
  }

  defp validate(name, model),
    do: Validation.validate_activity_schema(Map.fetch!(@slugs, name), model)

  defp slots(name) do
    common = [
      ["stem", "content"],
      ["choices", Access.at(0), "content"],
      ["authoring", "parts", Access.at(0), "hints", Access.at(0), "content"],
      ["authoring", "parts", Access.at(0), "responses", Access.at(0), "feedback", "content"],
      ["authoring", "parts", Access.at(0), "explanation", "content"]
    ]

    case name do
      "likert" -> [["items", Access.at(0), "content"] | common]
      _ -> common
    end
  end

  defp legacy(name, targeted) do
    model = @models[name]

    label =
      case name do
        "ordering" -> "Ordering"
        "check-all-that-apply" -> "CATA"
      end

    authoring = Map.delete(model["authoring"], "version")

    authoring =
      case targeted do
        true -> authoring
        false -> Map.delete(authoring, "targeted")
      end

    authoring =
      case name do
        "check-all-that-apply" ->
          Map.put(authoring, "incorrect", [["incorrect-choice"], "incorrect-response"])

        _ ->
          authoring
      end

    model
    |> Map.put(
      "type",
      case targeted do
        true -> "Targeted"
        false -> "Simple"
      end <> label
    )
    |> Map.put("authoring", authoring)
  end

  for {name, _slug} <- @slugs do
    test "#{name}: validates its factory, export, recursive rich text, and strict fields" do
      name = unquote(name)
      model = @models[name]
      assert :ok = validate(name, model)
      schema = SchemaResolver.resolve(name <> ".schema.json")
      assert :ok = JSONValidation.validate(schema, model)

      for {_element_name, element} <- @elements, slot <- slots(name) do
        assert :ok = validate(name, put_in(model, slot, [element]))

        assert :ok =
                 validate(name, put_in(model, slot, %{"model" => [element], "selection" => nil}))
      end

      for slot <- slots(name),
          bad <- [
            nil,
            %{},
            [%{}],
            [%{"type" => "unknown", "text" => "bypass"}],
            [
              %{
                "type" => "table",
                "children" => [%{"type" => "p", "children" => [%{"text" => "invalid nesting"}]}]
              }
            ]
          ] do
        assert {:error, [_ | _]} = validate(name, put_in(model, slot, bad))
      end

      paths = [
        ["authoring"],
        ["stem"],
        ["choices", Access.at(0)],
        ["authoring", "parts", Access.at(0)],
        ["authoring", "parts", Access.at(0), "hints", Access.at(0)],
        ["authoring", "parts", Access.at(0), "responses", Access.at(0)],
        ["authoring", "parts", Access.at(0), "responses", Access.at(0), "feedback"],
        ["authoring", "parts", Access.at(0), "explanation"]
      ]

      assert {:error, [_ | _]} = validate(name, Map.put(model, "explanaton", %{}))

      for path <- paths do
        assert {:error, [_ | _]} =
                 validate(name, update_in(model, path, &Map.put(&1, "explanaton", %{})))
      end

      for bad <- [
            nil,
            [],
            %{},
            Map.delete(model, "stem"),
            Map.put(model, "choices", []),
            put_in(model, ["authoring", "parts"], [])
          ] do
        assert {:error, [_ | _]} = validate(name, bad)
      end

      export = %{
        "id" => "activity",
        "type" => "Activity",
        "subType" => @slugs[name],
        "title" => "Question",
        "content" => model,
        "objectives" => %{},
        "tags" => []
      }

      root = SchemaResolver.resolve(name <> "-activity.schema.json")
      assert :ok = JSONValidation.validate(root, export)
      assert {:error, [_ | _]} = JSONValidation.validate(root, Map.put(export, "titel", "typo"))

      assert {:error, [_ | _]} =
               JSONValidation.validate(root, Map.put(export, "subType", "oli_multiple_choice"))

      assert {:error, [_ | _]} =
               JSONValidation.validate(root, put_in(export, ["content", "stem"], false))

      assert {:error, [_ | _]} = JSONValidation.validate(root, Map.delete(export, "title"))

      for result <-
            Task.async_stream(1..10, fn _ ->
              {SchemaResolver.resolve(name <> ".schema.json") == schema, validate(name, model)}
            end) do
        assert {:ok, {true, :ok}} == result
      end
    end
  end

  test "Ordering and CATA explicitly select V1/V2 and reject hybrid layouts" do
    for name <- ["ordering", "check-all-that-apply"] do
      model = @models[name]
      assert :ok = validate(name, legacy(name, false))
      assert :ok = validate(name, legacy(name, true))

      for bad <- [
            update_in(model, ["authoring"], &Map.delete(&1, "version")),
            put_in(model, ["authoring", "version"], 1),
            put_in(model, ["authoring", "version"], 3),
            put_in(legacy(name, true), ["authoring", "version"], 2),
            update_in(legacy(name, true), ["authoring"], &Map.delete(&1, "targeted")),
            put_in(legacy(name, false), ["authoring", "targeted"], [])
          ] do
        assert {:error, [_ | _]} = validate(name, bad)
      end

      for field <- ["correct", "targeted"] do
        assert {:error, [_ | _]} =
                 validate(name, update_in(model, ["authoring"], &Map.delete(&1, field)))
      end

      for field <- ["correct", "targeted"],
          bad <- [nil, false, [[1], "response"], [["choice"], "response", "extra"]] do
        assert {:error, [_ | _]} = validate(name, put_in(model, ["authoring", field], bad))
      end

      # Choice IDs need not exist or be unique yet: these are deliberately domain checks.
      assert :ok =
               validate(
                 name,
                 put_in(model, ["authoring", "correct"], [
                   ["missing", "missing"],
                   "missing-response"
                 ])
               )
    end

    cata = @models["check-all-that-apply"]

    assert {:error, [_ | _]} =
             validate(
               "check-all-that-apply",
               put_in(cata, ["authoring", "incorrect"], [["choice"], "response"])
             )

    assert {:error, [_ | _]} =
             validate(
               "check-all-that-apply",
               update_in(
                 legacy("check-all-that-apply", false),
                 ["authoring"],
                 &Map.delete(&1, "incorrect")
               )
             )

    assert {:error, [_ | _]} = validate("ordering", legacy("check-all-that-apply", false))
    assert {:error, [_ | _]} = validate("check-all-that-apply", legacy("ordering", false))
  end

  test "Ordering choice colours are typed pairs and do not leak to other activity schemas" do
    model = @models["ordering"]
    assert :ok = validate("ordering", Map.put(model, "choiceColors", [["choice", "#fff"]]))

    for bad <- [nil, [1], [["choice"]], [["choice", false]], [["choice", "red", "extra"]]] do
      assert {:error, [_ | _]} = validate("ordering", Map.put(model, "choiceColors", bad))
    end

    assert {:error, [_ | _]} =
             validate("ordering", Map.put(legacy("ordering", false), "choiceColors", []))

    assert {:error, [_ | _]} =
             validate(
               "check-all-that-apply",
               Map.put(@models["check-all-that-apply"], "choiceColors", [])
             )
  end

  test "Likert supports multipart items and typed Maybe values without relational checks" do
    model = @models["likert"]
    choice_path = ["choices", Access.at(0), "value"]
    group_path = ["items", Access.at(0), "group"]

    for value <- [%{"type" => 0}, %{"type" => 1, "value" => 4.5}] do
      assert :ok = validate("likert", put_in(model, choice_path, value))
    end

    for group <- [%{"type" => 0}, %{"type" => 1, "value" => "group"}] do
      assert :ok = validate("likert", put_in(model, group_path, group))
    end

    for bad <- [
          nil,
          5,
          %{},
          %{"type" => 2},
          %{"type" => 1},
          %{"type" => 1, "value" => "bad"},
          %{"type" => 0, "value" => 5},
          %{"type" => 0, "typo" => 1}
        ] do
      assert {:error, [_ | _]} = validate("likert", put_in(model, choice_path, bad))
    end

    assert {:error, [_ | _]} =
             validate("likert", put_in(model, group_path, %{"type" => 1, "value" => 5}))

    for field <- ["items", "orderDescending", "activityTitle"] do
      assert {:error, [_ | _]} = validate("likert", Map.delete(model, field))
    end

    assert {:error, [_ | _]} = validate("likert", Map.put(model, "items", []))

    assert {:error, [_ | _]} =
             validate("likert", put_in(model, ["items", Access.at(0), "required"], "yes"))

    assert {:error, [_ | _]} =
             validate("likert", put_in(model, ["items", Access.at(0), "requred"], true))

    assert {:error, [_ | _]} = validate("likert", put_in(model, ["authoring", "version"], 2))
    multi = update_in(model, ["authoring", "parts"], &(&1 ++ &1))
    assert :ok = validate("likert", multi)
    assert {:error, [_ | _]} = validate("ordering", @models["likert"])

    assert {:error, [_ | _]} =
             Validation.validate_activity_schema("oli_likert", @models["ordering"])
  end

  test "inherited client metadata remains explicit and cannot override type dispatch" do
    for {name, model} <- @models do
      with_metadata =
        Map.merge(model, %{
          "id" => "activity",
          "resourceId" => 1,
          "learningLanguage" => "en",
          "bibrefs" => ["1"],
          "activity_id" => "activity",
          "activityType" => %{"slug" => "oli_multiple_choice"},
          "content" => %{"opaque" => true}
        })

      assert :ok = validate(name, with_metadata)
      assert {:error, [_ | _]} = validate(name, Map.put(with_metadata, "activityTyp", "typo"))
      assert {:error, [_ | _]} = validate(name, Map.put(with_metadata, "resourceId", "1"))
      assert {:error, [_ | _]} = validate(name, Map.delete(with_metadata, "stem"))
    end
  end

  test "historical CATA export remains valid without weakening its tagged legacy contract" do
    path = "test/oli/interop/digest/2689.json"
    export = path |> File.read!() |> Jason.decode!()
    assert :ok = validate("check-all-that-apply", export["content"])

    assert :ok =
             JSONValidation.validate(
               SchemaResolver.resolve("check-all-that-apply-activity.schema.json"),
               export
             )
  end
end
