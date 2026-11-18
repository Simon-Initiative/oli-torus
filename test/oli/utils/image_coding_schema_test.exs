defmodule Oli.Utils.ImageCodingSchemaTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.{JSONValidation, SchemaResolver}
  alias Oli.Validation

  @models "test/support/fixtures/image_coding_models.json" |> File.read!() |> Jason.decode!()
  @elements "test/support/fixtures/basic_page_elements.json" |> File.read!() |> Jason.decode!()
  @required ~w(stem isExample starterCode solutionCode resourceURLs tolerance regex feedback authoring)

  defp validate(model), do: Validation.validate_activity_schema("oli_image_coding", model)
  defp part_path, do: ["authoring", "parts", Access.at(0)]

  test "validates real client factories and editor actions through the cached dispatcher" do
    for {_name, model} <- @models, do: assert(:ok == validate(model))
    assert @models["initial"]["authoring"]["parts"] |> hd() |> Map.fetch!("responses") == []
    root = SchemaResolver.resolve("image-coding.schema.json")
    assert root == SchemaResolver.resolve("image-coding.schema.json")

    for result <- Task.async_stream(1..12, fn _ -> validate(@models["edited"]) end),
        do: assert(result == {:ok, :ok})
  end

  test "reuses Basic Page rich content for stem, root feedback, hints, explanations and generic response feedback" do
    model = @models["edited"]

    response = %{
      "id" => "response",
      "rule" => "",
      "score" => 1,
      "feedback" => model["feedback"] |> hd()
    }

    model = put_in(model, part_path() ++ ["responses"], [response])

    for path <- [
          ["stem", "content"],
          ["feedback", Access.at(0), "content"],
          part_path() ++ ["hints", Access.at(0), "content"],
          part_path() ++ ["explanation", "content"],
          part_path() ++ ["responses", Access.at(0), "feedback", "content"]
        ] do
      for {_name, element} <- @elements do
        assert :ok = validate(put_in(model, path, [element]))
        assert :ok = validate(put_in(model, path, %{"model" => [element], "selection" => nil}))
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
        assert {:error, [_ | _]} = validate(put_in(model, path, bad))
      end
    end
  end

  test "requires declared fields and their correct scalar and array types" do
    model = @models["initial"]
    for key <- @required, do: assert({:error, [_ | _]} = validate(Map.delete(model, key)))

    for {key, bad} <- [
          {"isExample", "false"},
          {"isExample", 0},
          {"starterCode", []},
          {"solutionCode", nil},
          {"resourceURLs", "image.png"},
          {"resourceURLs", [1]},
          {"tolerance", "2"},
          {"tolerance", nil},
          {"regex", []},
          {"feedback", ["feedback"]},
          {"feedback", [%{}]},
          {"feedback", nil},
          {"authoring", nil}
        ] do
      assert {:error, [_ | _]} = validate(Map.put(model, key, bad))
    end

    for bad <- [nil, [], %{}, "activity"], do: assert({:error, [_ | _]} = validate(bad))

    for key <- ~w(parts previewText) do
      assert {:error, [_ | _]} = validate(update_in(model, ["authoring"], &Map.delete(&1, key)))
    end

    assert {:error, [_ | _]} = validate(put_in(model, ["authoring", "previewText"], 1))
    assert {:error, [_ | _]} = validate(put_in(model, ["authoring", "parts"], %{}))
  end

  test "rejects unknown fields in all authored wrappers" do
    model = @models["edited"]
    assert {:error, [_ | _]} = validate(Map.put(model, "typo", true))

    for path <- [
          ["stem"],
          ["feedback", Access.at(0)],
          ["authoring"],
          part_path(),
          part_path() ++ ["hints", Access.at(0)],
          part_path() ++ ["explanation"]
        ] do
      assert {:error, [_ | _]} = validate(update_in(model, path, &Map.put(&1, "typo", true)))
    end

    for key <- ~w(version transformations targeted responses) do
      assert {:error, [_ | _]} = validate(put_in(model, ["authoring", key], []))
    end

    for key <- ~w(output canvas customScoring scoringStrategy) do
      assert {:error, [_ | _]} = validate(Map.put(model, key, []))
    end
  end

  test "supports inherited metadata without allowing malformed known fields" do
    model =
      Map.merge(@models["initial"], %{
        "id" => "image-coding",
        "activity_id" => "activity",
        "resourceId" => 1,
        "learningLanguage" => "en",
        "bibrefs" => ["reference"],
        "activityType" => %{"opaque" => true},
        "content" => [nil]
      })

    assert :ok = validate(model)

    for {key, bad} <- [
          {"resourceId", "1"},
          {"id", 1},
          {"bibrefs", [1]},
          {"learningLanguage", false}
        ],
        do: assert({:error, [_ | _]} = validate(Map.put(model, key, bad)))
  end

  test "generic responses keep math opaque but wrappers strict" do
    model = @models["initial"]
    response = %{"id" => "response", "score" => 1, "feedback" => hd(model["feedback"])}
    path = part_path() ++ ["responses", Access.at(0), "matchConfig"]
    model = put_in(model, part_path() ++ ["responses"], [response])
    deep = Enum.reduce(1..1000, %{}, fn _, acc -> %{"next" => acc} end)

    for math <- [%{}, deep, %{"$ref" => "https://invalid.example/data", "future" => [nil, true]}] do
      assert :ok =
               validate(
                 put_in(model, path, %{
                   "version" => 1,
                   "type" => "math_expression",
                   "math" => math
                 })
               )
    end

    assert :ok = validate(put_in(model, path, %{"version" => 1, "type" => "always"}))

    for bad <- [
          nil,
          %{},
          %{"version" => 2, "type" => "always"},
          %{"version" => 1, "type" => "always", "typo" => true},
          %{"version" => 1, "type" => "math_expression", "math" => []}
        ] do
      assert {:error, [_ | _]} = validate(put_in(model, path, bad))
    end

    assert {:error, [_ | _]} = validate(model)
    model = put_in(model, part_path() ++ ["responses", Access.at(0), "rule"], "")
    assert :ok = validate(model)

    assert {:error, [_ | _]} =
             validate(put_in(model, part_path() ++ ["responses", Access.at(0), "typo"], true))

    assert {:error, [_ | _]} =
             validate(
               put_in(model, part_path() ++ ["responses", Access.at(0), "feedback", "typo"], true)
             )
  end

  test "defers executable content, URL policies, tolerance bounds and readiness checks" do
    model =
      Map.merge(@models["initial"], %{
        "starterCode" => "not valid code {",
        "solutionCode" => "",
        "regex" => "[",
        "tolerance" => -1.5,
        "resourceURLs" => ["", "relative address", "relative address"]
      })

    assert :ok = validate(model)
    assert :ok = validate(Map.put(model, "feedback", []))
    assert :ok = validate(Map.put(model, "feedback", [hd(model["feedback"])]))
    assert :ok = validate(put_in(model, ["authoring", "parts"], []))

    assert :ok =
             validate(
               put_in(
                 model,
                 ["authoring", "parts"],
                 model["authoring"]["parts"] ++ model["authoring"]["parts"]
               )
             )

    assert :ok = validate(put_in(model, part_path() ++ ["hints"], []))
  end

  test "export schema enforces exact subtype, envelope and nested model" do
    root = SchemaResolver.resolve("image-coding-activity.schema.json")

    export = %{
      "id" => "activity",
      "type" => "Activity",
      "subType" => "oli_image_coding",
      "title" => "Image Coding",
      "content" => @models["initial"]
    }

    assert :ok = JSONValidation.validate(root, export)

    for bad <- [
          Map.put(export, "subType", "oli_directed_discussion"),
          Map.put(export, "type", "Page"),
          Map.put(export, "typo", true),
          Map.delete(export, "title"),
          put_in(export, ["content", "tolerance"], "2")
        ] do
      assert {:error, [_ | _]} = JSONValidation.validate(root, bad)
    end
  end
end
