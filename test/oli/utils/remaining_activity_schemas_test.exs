defmodule Oli.Utils.RemainingActivitySchemasTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.{JSONValidation, SchemaResolver}
  alias Oli.Validation

  @models "test/support/fixtures/remaining_activity_models.json"
          |> File.read!()
          |> Jason.decode!()
  @elements "test/support/fixtures/basic_page_elements.json" |> File.read!() |> Jason.decode!()
  @slugs %{
    "image-hotspot" => "oli_image_hotspot",
    "oli-embedded" => "oli_embedded",
    "lti-external-tool" => "lti_external_tool",
    "logic-lab" => "oli_logic_lab",
    "vlab" => "oli_vlab"
  }
  defp validate(name, model), do: Validation.validate_activity_schema(@slugs[name], model)
  defp part_path, do: ["authoring", "parts", Access.at(0)]
  defp response_path, do: part_path() ++ ["responses", Access.at(0)]

  test "every activity manifest has explicit dispatch and an exact export schema" do
    schemas = SchemaResolver.all()

    for path <- Path.wildcard("assets/src/components/activities/*/manifest.json") do
      manifest = path |> File.read!() |> Jason.decode!()
      slug = manifest["id"]
      assert {:error, [_ | _]} = Validation.validate_activity_schema(slug, nil)

      matches =
        Enum.filter(schemas, fn entry ->
          get_in(entry.schema, ["allOf", Access.at(1), "properties", "subType", "const"]) == slug
        end)

      assert length(matches) == 1
    end
  end

  for {name, slug} <- @slugs do
    test "#{name} validates factories, cached reuse and exact export dispatch" do
      name = unquote(name)
      for key <- [name, name <> "-edited"], do: assert(:ok = validate(name, @models[key]))
      model = @models[name]
      root = SchemaResolver.resolve(name <> ".schema.json")
      assert root == SchemaResolver.resolve(name <> ".schema.json")

      for result <- Task.async_stream(1..8, fn _ -> validate(name, model) end),
          do: assert(result == {:ok, :ok})

      export_root = SchemaResolver.resolve(name <> "-activity.schema.json")

      export = %{
        "id" => "activity",
        "type" => "Activity",
        "subType" => unquote(slug),
        "title" => "Activity",
        "content" => model
      }

      assert :ok = JSONValidation.validate(export_root, export)

      for bad <- [
            Map.put(export, "subType", "oli_adaptive"),
            Map.put(export, "type", "Page"),
            Map.put(export, "typo", true),
            Map.delete(export, "title"),
            Map.put(export, "content", %{})
          ] do
        assert {:error, [_ | _]} = JSONValidation.validate(export_root, bad)
      end

      for bad <- [nil, [], %{}, Map.put(model, "typo", true), Map.delete(model, "authoring")],
          do: assert({:error, [_ | _]} = validate(name, bad))

      for {field, _value} <- model,
          field not in ["imageURL", "resourceVerification", "context"] do
        assert {:error, [_ | _]} = validate(name, Map.delete(model, field))
      end
    end

    test "#{name} shares rich-content and opaque math while closing authored wrappers" do
      name = unquote(name)
      model = @models[name]

      content = %{
        "id" => "content",
        "content" => [%{"type" => "p", "children" => [%{"text" => "Text"}]}]
      }

      response = %{"id" => "response", "rule" => "", "score" => 1, "feedback" => content}

      model =
        model
        |> put_in(part_path() ++ ["responses"], [response])
        |> put_in(part_path() ++ ["hints"], [content])
        |> put_in(part_path() ++ ["explanation"], content)

      slots = [
        part_path() ++ ["hints", Access.at(0), "content"],
        part_path() ++ ["explanation", "content"],
        response_path() ++ ["feedback", "content"]
      ]

      slots =
        case Map.has_key?(model, "stem") do
          true -> [["stem", "content"] | slots]
          false -> slots
        end

      slots =
        case name do
          "logic-lab" -> [["feedback", Access.at(0), "content"] | slots]
          _ -> slots
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

        for bad <- [nil, %{}, [%{}], [%{"type" => "unknown"}]],
            do: assert({:error, [_ | _]} = validate(name, put_in(model, path, bad)))
      end

      for path <- [["authoring"], part_path(), response_path(), response_path() ++ ["feedback"]],
          do:
            assert(
              {:error, [_ | _]} =
                validate(name, update_in(model, path, &Map.put(&1, "typo", true)))
            )

      deep = Enum.reduce(1..1000, %{}, fn _, acc -> %{"next" => acc} end)
      model = update_in(model, response_path(), &Map.delete(&1, "rule"))
      path = response_path() ++ ["matchConfig"]

      for math <- [
            %{},
            deep,
            %{"$ref" => "https://invalid.example/data", "future" => [nil, true]}
          ],
          do:
            assert(
              :ok =
                validate(
                  name,
                  put_in(model, path, %{
                    "version" => 1,
                    "type" => "math_expression",
                    "math" => math
                  })
                )
            )

      for bad <- [
            %{},
            %{"version" => 1, "type" => "always", "typo" => true},
            %{"version" => 1, "type" => "math_expression", "math" => []}
          ],
          do: assert({:error, [_ | _]} = validate(name, put_in(model, path, bad)))

      assert :ok = validate(name, put_in(model, ["authoring", "parts"], []))
    end
  end

  test "hotspot geometry and content are typed, not evaluated" do
    model = @models["image-hotspot-edited"]

    for {_label, element} <- @elements do
      assert :ok =
               validate(
                 "image-hotspot",
                 put_in(model, ["choices", Access.at(0), "content"], [element])
               )
    end

    for {key, bad} <- [{"coords", ["1"]}, {"coords", nil}, {"title", 1}, {"typo", true}],
        do:
          assert(
            {:error, [_ | _]} =
              validate("image-hotspot", put_in(model, ["choices", Access.at(0), key], bad))
          )

    for {key, bad} <- [{"imageURL", nil}, {"height", "400"}, {"width", nil}, {"multiple", "true"}],
        do: assert({:error, [_ | _]} = validate("image-hotspot", Map.put(model, key, bad)))

    assert :ok =
             validate("image-hotspot", put_in(model, ["choices", Access.at(0), "coords"], [-1.5]))

    assert :ok = validate("image-hotspot", Map.put(model, "choices", []))
    assert :ok = validate("image-hotspot", put_in(model, ["authoring", "correct"], [[], ""]))

    assert {:error, [_ | _]} =
             validate("image-hotspot", put_in(model, ["authoring", "correct"], [[], 1]))
  end

  test "embedded verification records and bundle status are strict without XML policy" do
    model = @models["oli-embedded-edited"]
    assert :ok = validate("oli-embedded", Map.put(model, "modelXml", "unparsed XML <"))

    for {key, bad} <- [
          {"base", 1},
          {"src", nil},
          {"resourceBase", []},
          {"resourceURLs", [1]},
          {"suppressReviewInteraction", "true"},
          {"bundleStatus", %{"code" => "x"}},
          {"bundleStatus", %{"code" => "x", "message" => "y", "typo" => true}},
          {"resourceVerification", %{"asset" => "unknown"}}
        ],
        do: assert({:error, [_ | _]} = validate("oli-embedded", Map.put(model, key, bad)))
  end

  test "LTI deep-link wrapper is closed and custom values are arbitrary JSON" do
    model = @models["lti-external-tool-edited"]

    assert :ok =
             validate(
               "lti-external-tool",
               update_in(model, ["authoring"], &Map.delete(&1, "previewText"))
             )

    assert :ok =
             validate(
               "lti-external-tool",
               put_in(model, ["deepLink", "custom"], %{"$ref" => "data", "nested" => [nil, %{}]})
             )

    for {key, bad} <- [
          {"openInNewTab", "true"},
          {"height", "600"},
          {"deepLink", %{}},
          {"deepLink", nil}
        ],
        do: assert({:error, [_ | _]} = validate("lti-external-tool", Map.put(model, key, bad)))

    for {key, bad} <- [{"type", "unknown"}, {"url", 1}, {"custom", []}, {"typo", true}],
        do:
          assert(
            {:error, [_ | _]} =
              validate("lti-external-tool", put_in(model, ["deepLink", key], bad))
          )
  end

  test "Logic Lab activity supports IDs and typed specifications with explicit open extensions" do
    model = @models["logic-lab-edited"]
    assert :ok = validate("logic-lab", Map.put(model, "activity", "lab-id"))

    for type <- ~w(parse_tree chase_truth truth_table truth_tree derivation argument_diagram),
        do: assert(:ok = validate("logic-lab", put_in(model, ["activity", "spec", "type"], type)))

    assert :ok =
             validate(
               "logic-lab",
               put_in(model, ["activity", "spec", "future"], %{"opaque" => [nil, true]})
             )

    for {path, bad} <- [
          {["activity", "typo"], true},
          {["activity", "keywords"], [1]},
          {["activity", "spec", "type"], "unknown"},
          {["activity", "spec", "maximumScore"], "3"},
          {["activity", "spec", "objectives", Access.at(0), "mode"], "unknown"},
          {["activity", "spec", "objectives", Access.at(0), "typo"], true},
          {["context", "typo"], true},
          {["authoring", "version"], 2},
          {["authoring", "source"], []}
        ],
        do: assert({:error, [_ | _]} = validate("logic-lab", put_in(model, path, bad)))

    for bad <- [nil, [], 1],
        do: assert({:error, [_ | _]} = validate("logic-lab", Map.put(model, "activity", bad)))
  end

  test "Virtual Lab types XML settings, input variants and retained editor fields" do
    model = @models["vlab-edited"]

    for key <-
          ~w(assignmentSource assignmentPath assignment configuration reactions solutions species spectra) do
      assert :ok = validate("vlab", Map.put(model, key, "unparsed <"))
      assert {:error, [_ | _]} = validate("vlab", Map.put(model, key, nil))
    end

    for key <- ~w(species parameter) do
      assert {:error, [_ | _]} =
               validate("vlab", update_in(model, ["inputs", Access.at(4)], &Map.delete(&1, key)))

      assert {:error, [_ | _]} = validate("vlab", put_in(model, ["inputs", Access.at(4), key], 1))
    end

    for {key, bad} <- [
          {"inputType", "math_expression"},
          {"choiceIds", [1]},
          {"typo", true},
          {"size", "small"},
          {"itemConfig", %{}}
        ],
        do:
          assert(
            {:error, [_ | _]} =
              validate("vlab", put_in(model, ["inputs", Access.at(0), key], bad))
          )

    assert :ok =
             validate(
               "vlab",
               put_in(model, ["inputs", Access.at(4), "parameter"], "future-parameter")
             )

    assert :ok =
             validate("vlab", put_in(model, ["inputs", Access.at(0), "partId"], "missing-part"))

    assert :ok = validate("vlab", Map.put(model, "inputs", []))

    for {_label, element} <- @elements,
        do:
          assert(
            :ok = validate("vlab", put_in(model, ["choices", Access.at(0), "content"], [element]))
          )
  end
end
