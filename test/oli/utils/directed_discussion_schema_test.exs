defmodule Oli.Utils.DirectedDiscussionSchemaTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.{JSONValidation, SchemaResolver}
  alias Oli.Validation

  @models "test/support/fixtures/directed_discussion_models.json"
          |> File.read!()
          |> Jason.decode!()
  @elements "test/support/fixtures/basic_page_elements.json" |> File.read!() |> Jason.decode!()
  @participation_fields ~w(minPosts maxPosts minReplies maxReplies maxWordLength)

  defp validate(model), do: Validation.validate_activity_schema("oli_directed_discussion", model)
  defp part_path, do: ["authoring", "parts", Access.at(0)]
  defp response_path, do: part_path() ++ ["responses", Access.at(0)]

  test "validates shared client factory and editor fixtures through the cached dispatcher" do
    for {_name, model} <- @models, do: assert(:ok == validate(model))
    root = SchemaResolver.resolve("directed-discussion.schema.json")
    assert root == SchemaResolver.resolve("directed-discussion.schema.json")

    for result <- Task.async_stream(1..12, fn _ -> validate(@models["edited"]) end),
        do: assert(result == {:ok, :ok})
  end

  test "reuses Basic Page rich content in every discussion content slot" do
    model = @models["edited"]

    for path <- [
          ["stem", "content"],
          part_path() ++ ["hints", Access.at(0), "content"],
          part_path() ++ ["explanation", "content"],
          response_path() ++ ["feedback", "content"]
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

  test "requires root structure and all numeric participation fields" do
    model = @models["initial"]

    for key <- ~w(stem participation maxWords authoring) do
      assert {:error, [_ | _]} = validate(Map.delete(model, key))
    end

    for key <- @participation_fields do
      assert {:error, [_ | _]} =
               validate(update_in(model, ["participation"], &Map.delete(&1, key)))

      for bad <- [nil, "2", true, [], %{}] do
        assert {:error, [_ | _]} = validate(put_in(model, ["participation", key], bad))
      end
    end

    for bad <- [nil, [], %{}, "discussion"], do: assert({:error, [_ | _]} = validate(bad))

    for bad <- [nil, "250", true, %{}] do
      assert {:error, [_ | _]} = validate(Map.put(model, "maxWords", bad))
    end
  end

  test "versioned authoring is strict without fields from other activity types" do
    model = @models["initial"]

    for key <- ~w(version parts transformations) do
      assert {:error, [_ | _]} = validate(update_in(model, ["authoring"], &Map.delete(&1, key)))
    end

    for bad <- [nil, 0, 2, "1", true] do
      assert {:error, [_ | _]} = validate(put_in(model, ["authoring", "version"], bad))
    end

    for key <- ~w(previewText targeted responses) do
      assert {:error, [_ | _]} = validate(put_in(model, ["authoring", key], []))
    end

    for bad <- [nil, %{}, "parts"] do
      assert {:error, [_ | _]} = validate(put_in(model, ["authoring", "parts"], bad))
      assert {:error, [_ | _]} = validate(put_in(model, ["authoring", "transformations"], bad))
    end

    assert {:error, [_ | _]} =
             validate(
               put_in(model, ["authoring", "transformations"], [%{"operation" => "unknown"}])
             )
  end

  test "closes root, participation, content, part, response, and transformation wrappers" do
    model = @models["edited"]
    assert {:error, [_ | _]} = validate(Map.put(model, "typo", true))

    for path <- [
          ["participation"],
          ["stem"],
          ["authoring"],
          part_path(),
          part_path() ++ ["hints", Access.at(0)],
          part_path() ++ ["explanation"],
          response_path(),
          response_path() ++ ["feedback"],
          ["authoring", "transformations", Access.at(0)]
        ] do
      assert {:error, [_ | _]} = validate(update_in(model, path, &Map.put(&1, "typo", true)))
    end

    # Discussion posts and participation progress are delivery data, not authored configuration.
    for key <- ~w(posts replies progress customScoring scoringStrategy) do
      assert {:error, [_ | _]} = validate(Map.put(model, key, []))
    end
  end

  test "supports inherited metadata with typed fields" do
    model =
      Map.merge(@models["initial"], %{
        "id" => "discussion",
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
        ] do
      assert {:error, [_ | _]} = validate(Map.put(model, key, bad))
    end
  end

  test "generic Part match configurations preserve the shared opaque math leaf" do
    model = @models["initial"]
    path = response_path() ++ ["matchConfig"]
    model = update_in(model, response_path(), &Map.delete(&1, "rule"))
    deep = Enum.reduce(1..1000, %{}, fn _, acc -> %{"next" => acc} end)

    for math <- [
          %{},
          deep,
          %{"future" => [nil, %{"unknown" => true}], "$ref" => "https://invalid.example/data"}
        ] do
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
          %{"version" => 1, "type" => "math_expression"},
          %{"version" => 1, "type" => "math_expression", "math" => []}
        ] do
      assert {:error, [_ | _]} = validate(put_in(model, path, bad))
    end

    assert {:error, [_ | _]} = validate(model)
  end

  test "defers participation policies, readiness, and part domain checks" do
    model = @models["initial"]

    participation = %{
      "minPosts" => 10.5,
      "maxPosts" => -2,
      "minReplies" => 5,
      "maxReplies" => 1,
      "maxWordLength" => -0.5
    }

    assert :ok =
             validate(Map.merge(model, %{"participation" => participation, "maxWords" => -2.5}))

    assert :ok = validate(put_in(model, ["authoring", "parts"], []))

    assert :ok =
             validate(
               put_in(
                 model,
                 ["authoring", "parts"],
                 model["authoring"]["parts"] ++ model["authoring"]["parts"]
               )
             )

    assert :ok = validate(put_in(model, part_path() ++ ["responses"], []))
    assert :ok = validate(put_in(model, part_path() ++ ["hints"], []))
    assert :ok = validate(put_in(model, part_path() ++ ["targets"], ["missing-target"]))
  end

  test "export schema checks exact subtype, closed envelope and nested model" do
    root = SchemaResolver.resolve("directed-discussion-activity.schema.json")

    export = %{
      "id" => "activity",
      "type" => "Activity",
      "subType" => "oli_directed_discussion",
      "title" => "Discussion",
      "content" => @models["initial"]
    }

    assert :ok = JSONValidation.validate(root, export)

    for bad <- [
          Map.put(export, "subType", "oli_multi_input"),
          Map.put(export, "type", "Page"),
          Map.put(export, "typo", true),
          Map.delete(export, "title"),
          put_in(export, ["content", "participation", "minPosts"], "2")
        ] do
      assert {:error, [_ | _]} = JSONValidation.validate(root, bad)
    end
  end
end
