defmodule Oli.Validation.ActivityDomainTest do
  use ExUnit.Case, async: true
  alias Oli.Validation
  alias Oli.Validation.ActivityContracts
  alias Oli.Validation.ActivityDomain.Limits
  alias Oli.MCP.ActivityInput

  @mc "test/support/fixtures/multiple_choice_model.json" |> File.read!() |> Jason.decode!()
  @choices "test/support/fixtures/choice_family_models.json" |> File.read!() |> Jason.decode!()
  @short "test/support/fixtures/upload_short_answer_models.json"
         |> File.read!()
         |> Jason.decode!()
  @multi "test/support/fixtures/multi_input_models.json" |> File.read!() |> Jason.decode!()
  @dnd "test/support/fixtures/custom_dnd_response_multi_models.json"
       |> File.read!()
       |> Jason.decode!()
  @remaining "test/support/fixtures/remaining_activity_models.json"
             |> File.read!()
             |> Jason.decode!()
  @image "test/support/fixtures/image_coding_models.json" |> File.read!() |> Jason.decode!()
  @discussion "test/support/fixtures/directed_discussion_models.json"
              |> File.read!()
              |> Jason.decode!()
  defp part, do: ["authoring", "parts", Access.at(0)]
  defp response(i), do: part() ++ ["responses", Access.at(i)]
  defp domain(model), do: Validation.validate_activity_domain("oli_multiple_choice", model)
  defp codes({:error, issues}), do: Enum.map(issues, & &1.code)

  test "all sixteen Basic Page factories pass separate APIs; Adaptive is explicitly excluded" do
    models = %{
      "oli_multiple_choice" => @mc,
      "oli_ordering" => @choices["ordering"],
      "oli_check_all_that_apply" => @choices["check-all-that-apply"],
      "oli_likert" => @choices["likert"],
      "oli_short_answer" => @short["short-answer"],
      "oli_file_upload" => @short["file-upload"],
      "oli_multi_input" => @multi["text"],
      "oli_response_multi" => @dnd["response-multi-grouped"],
      "oli_custom_dnd" => @dnd["custom-dnd"],
      "oli_image_coding" => @image["initial"],
      "oli_directed_discussion" => @discussion["initial"],
      "oli_image_hotspot" => @remaining["image-hotspot"],
      "oli_embedded" => @remaining["oli-embedded"],
      "lti_external_tool" => @remaining["lti-external-tool"],
      "oli_logic_lab" => @remaining["logic-lab"],
      "oli_vlab" => @remaining["vlab"]
    }

    assert map_size(models) == 16

    for {slug, model} <- models do
      assert :ok = Validation.validate_activity_schema(slug, model), slug
      assert :ok = Validation.validate_activity_domain(slug, model), slug
    end

    assert map_size(ActivityContracts.all()) == 17

    for slug <- ["oli_adaptive", "unknown"],
        do:
          assert(
            "unsupported_activity_type" in codes(Validation.validate_activity_domain(slug, @mc))
          )
  end

  test "schema remains independent; MCP stops at JSON, schema, or domain failure" do
    bad = put_in(@mc, response(0) ++ ["rule"], "not a rule")
    assert :ok = Validation.validate_activity_schema("oli_multiple_choice", bad)
    assert "invalid_rule" in codes(domain(bad))

    assert {:error, %{stage: "schema"}} =
             ActivityInput.validate_json(
               "oli_multiple_choice",
               Jason.encode!(Map.delete(bad, "stem"))
             )

    assert {:error, %{stage: "domain"}} =
             ActivityInput.validate_json("oli_multiple_choice", Jason.encode!(bad))

    assert {:error, %{stage: "json"}} =
             ActivityInput.validate_json("oli_multiple_choice", "{ invalid json")

    assert {:ok, @mc} = ActivityInput.validate_json("oli_multiple_choice", Jason.encode!(@mc))
  end

  test "duplicate definitions report both paths and normalize numeric IDs without mutation" do
    model = put_in(@mc, ["choices", Access.at(0), "id"], @mc["stem"]["id"])
    assert {:error, [issue]} = domain(model)
    assert issue.code == "duplicate_id"
    assert issue.path == "/choices/0/id"
    assert issue.related_paths == ["/stem/id"]
    assert get_in(model, ["choices", Access.at(0), "id"]) == @mc["stem"]["id"]

    model =
      @mc
      |> put_in(["stem", "content", Access.at(0), "id"], 1)
      |> put_in(["choices", Access.at(0), "content", Access.at(0), "id"], "1")

    assert "duplicate_id" in codes(domain(model))
  end

  test "intentional bindings do not hide duplicate inputs, references, Likert items or parts" do
    model = @multi["text"]
    assert :ok = Validation.validate_activity_domain("oli_multi_input", model)

    assert "duplicate_id" in codes(
             Validation.validate_activity_domain(
               "oli_multi_input",
               Map.put(model, "inputs", model["inputs"] ++ model["inputs"])
             )
           )

    ref = get_in(model, ["stem", "content", Access.at(0), "children", Access.at(1)])
    bad = update_in(model, ["stem", "content", Access.at(0), "children"], &(&1 ++ [ref]))
    assert "duplicate_id" in codes(Validation.validate_activity_domain("oli_multi_input", bad))
    likert = @choices["likert"]
    assert :ok = Validation.validate_activity_domain("oli_likert", likert)

    assert "duplicate_id" in codes(
             Validation.validate_activity_domain(
               "oli_likert",
               Map.put(likert, "items", likert["items"] ++ likert["items"])
             )
           )

    bad =
      put_in(
        likert,
        ["authoring", "parts"],
        likert["authoring"]["parts"] ++ likert["authoring"]["parts"]
      )

    assert "duplicate_id" in codes(Validation.validate_activity_domain("oli_likert", bad))
  end

  test "invalid grammar, trailing garbage, parser exceptions and invalid regex fail closed" do
    for rule <- [
          ".*",
          "",
          "input like {a} trailing",
          "input like {a} || input like {b} || input like {.*}",
          "input like {a} && input like {b} && input like {c}"
        ] do
      assert "invalid_rule" in codes(domain(put_in(@mc, response(0) ++ ["rule"], rule)))
    end

    assert "invalid_regex" in codes(
             domain(put_in(@mc, response(0) ++ ["rule"], "input like {[}"))
           )

    assert "input_limit_exceeded" in codes(
             domain(put_in(@mc, response(0) ++ ["rule"], String.duplicate("x", 32_769)))
           )
  end

  test "terminal catch-all uses complete AST, including grouped input wildcards" do
    for rule <- [
          "input like {.*}",
          "(input like {.*})"
        ],
        do: assert(:ok = domain(put_in(@mc, response(1) ++ ["rule"], rule)))

    response_multi =
      put_in(
        @dnd["response-multi"],
        response(1) ++ ["rule"],
        "input_ref_a like {.*} && (input_ref_b like {.*})"
      )

    assert :ok = Validation.validate_activity_domain("oli_response_multi", response_multi)

    assert "missing_terminal_catch_all" in codes(
             domain(put_in(@mc, response(1) ++ ["rule"], "input_ref_a like {.*}"))
           )

    for rule <- [
          "(!(input like {.*}))",
          "input like {.*} && (attemptNumber > {1})",
          "input equals {.*}"
        ],
        do:
          assert(
            "missing_terminal_catch_all" in codes(
              domain(put_in(@mc, response(1) ++ ["rule"], rule))
            )
          )

    assert "missing_terminal_catch_all" in codes(domain(put_in(@mc, part() ++ ["responses"], [])))
    assert ["invalid_rule"] = codes(domain(put_in(@mc, response(1) ++ ["rule"], "invalid")))
  end

  test "manual and delegated policies permit empty tables but still check provided rules" do
    for {slug, model} <- [
          {"oli_file_upload", @short["file-upload"]},
          {"oli_directed_discussion", @discussion["initial"]},
          {"oli_image_coding", @image["initial"]},
          {"oli_embedded", @remaining["oli-embedded"]},
          {"oli_logic_lab", @remaining["logic-lab"]},
          {"lti_external_tool", @remaining["lti-external-tool"]}
        ] do
      assert :ok =
               Validation.validate_activity_domain(
                 slug,
                 put_in(model, part() ++ ["responses"], [])
               )
    end

    assert :ok =
             domain(
               @mc
               |> put_in(part() ++ ["gradingApproach"], "manual")
               |> put_in(part() ++ ["responses"], [])
             )

    bad = put_in(@short["file-upload"], response(0) ++ ["rule"], "bad rule")
    assert "invalid_rule" in codes(Validation.validate_activity_domain("oli_file_upload", bad))
  end

  test "structured matchConfig takes precedence while empty and omitted rule strings are valid" do
    model = @short["math-expression"]
    assert :ok = Validation.validate_activity_domain("oli_short_answer", model)

    assert :ok =
             Validation.validate_activity_domain(
               "oli_short_answer",
               update_in(model, response(1), &Map.delete(&1, "rule"))
             )

    bad =
      model
      |> put_in(response(1) ++ ["matchConfig"], %{
        "version" => 1,
        "type" => "math_expression",
        "math" => %{}
      })
      |> put_in(response(1) ++ ["rule"], "input like {.*}")

    assert ["invalid_match_config"] =
             codes(Validation.validate_activity_domain("oli_short_answer", bad))

    assert "invalid_rule" in codes(
             Validation.validate_activity_domain(
               "oli_short_answer",
               put_in(model, response(0) ++ ["rule"], "bad stale rule")
             )
           )
  end

  test "effective config preparation accepts unit policy supplied at item level" do
    config = %{
      "version" => 1,
      "type" => "math_expression",
      "math" => %{"mode" => "unit_aware", "expected" => "3x m/s"}
    }

    item = %{
      "version" => 1,
      "type" => "math_expression",
      "subtype" => "expression_with_units",
      "config" => %{"unitPolicy" => %{"type" => "convertible_units", "units" => ["m/s", "km/hr"]}}
    }

    assert {:error, _} = Oli.Math.Match.decode_config(config)

    assert {:ok, _} =
             config |> Oli.Math.MatchConfig.prepare(item) |> Oli.Math.Match.decode_config()

    model =
      @short["math-expression"]
      |> put_in(response(0) ++ ["matchConfig"], config)
      |> Map.put("itemConfig", item)

    assert :ok = Validation.validate_activity_schema("oli_short_answer", model)
    assert :ok = Validation.validate_activity_domain("oli_short_answer", model)
    multi = @multi["converted"] |> put_in(["inputs", Access.at(3), "itemConfig"], item)

    part_id = multi["inputs"] |> Enum.at(3) |> Map.fetch!("partId")
    part_index = Enum.find_index(multi["authoring"]["parts"], &(&1["id"] == part_id))

    multi =
      put_in(
        multi,
        ["authoring", "parts", Access.at(part_index), "responses", Access.at(0), "matchConfig"],
        config
      )

    assert :ok = Validation.validate_activity_domain("oli_multi_input", multi)
  end

  test "cached identical response configs remain isolated by effective item context" do
    config = %{
      "version" => 1,
      "type" => "math_expression",
      "math" => %{"mode" => "unit_aware", "expected" => "3x m/s"}
    }

    item = %{
      "version" => 1,
      "type" => "math_expression",
      "subtype" => "expression_with_units",
      "config" => %{"unitPolicy" => %{"type" => "convertible_units", "units" => ["m/s", "km/hr"]}}
    }

    model = @multi["converted"] |> put_in(["inputs", Access.at(2), "itemConfig"], item)

    model =
      Enum.reduce([2, 3], model, fn index, model ->
        put_in(
          model,
          ["authoring", "parts", Access.at(index), "responses", Access.at(0), "matchConfig"],
          config
        )
      end)

    assert :ok = Validation.validate_activity_schema("oli_multi_input", model)
    assert {:error, [issue]} = Validation.validate_activity_domain("oli_multi_input", model)
    assert issue.code == "invalid_match_config"
    assert issue.path == "/authoring/parts/3/responses/0/matchConfig"
  end

  test "opaque metadata and expression IDs are excluded from the generic ID index" do
    assert :ok = domain(Map.put(@mc, "activityType", %{"id" => @mc["stem"]["id"]}))

    metadata =
      put_in(@mc, ["stem", "content", Access.at(0), "content"], %{"id" => @mc["stem"]["id"]})

    assert :ok = domain(metadata)

    popup = %{
      "type" => "popup",
      "children" => [%{"text" => "Click"}],
      "content" => [
        %{"type" => "p", "id" => @mc["stem"]["id"], "children" => [%{"text" => "Popup"}]}
      ]
    }

    assert "duplicate_id" in codes(domain(put_in(@mc, ["stem", "content"], [popup])))

    model =
      put_in(@short["math-expression"], response(0) ++ ["matchConfig", "math", "extension"], %{
        "id" => @short["math-expression"]["stem"]["id"]
      })

    assert :ok = Validation.validate_activity_domain("oli_short_answer", model)
  end

  test "limits bound decoding, traversal and diagnostics; direct misuse fails closed" do
    assert {:error, _} = Limits.decode(String.duplicate(" ", 4 * 1024 * 1024 + 1))
    assert {:error, _} = Limits.decode(String.duplicate("[", 129) <> String.duplicate("]", 129))
    assert {:error, _} = Limits.check(List.duplicate(nil, 100_001))
    assert :ok = Limits.check(List.duplicate(nil, 99_999))
    assert {:error, _} = Limits.check(%{"opaque" => String.duplicate("x", 4 * 1024 * 1024 + 1)})

    assert Oli.Validation.ActivityDomain.Issue.pointer(["a/b~c", 0, "items"]) ==
             "/items/0/a~1b~0c"

    assert "invalid_input_shape" in codes(domain(%{}))

    assert {:ok, %{"value" => _}} =
             Limits.decode(Jason.encode!(%{"value" => String.duplicate("{[\"", 200)}))

    model = Map.put(@mc, "choices", List.duplicate(hd(@mc["choices"]), 300))
    assert {:error, issues} = domain(model)
    assert length(issues) <= 100
    assert domain(model) == domain(model)
  end
end
