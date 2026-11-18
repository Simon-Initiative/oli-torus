defmodule Oli.Utils.AdaptivePageSchemaTest do
  use ExUnit.Case, async: true

  alias Oli.Utils.{JSONValidation, SchemaResolver}

  @models "test/support/fixtures/adaptive_page_models.json" |> File.read!() |> Jason.decode!()
  defp validate(model),
    do:
      JSONValidation.validate(SchemaResolver.resolve("page-content-adaptive.schema.json"), model)

  defp generic(model),
    do: JSONValidation.validate(SchemaResolver.resolve("page-content.schema.json"), model)

  defp group_path, do: ["model", Access.at(0)]
  defp ref_path, do: group_path() ++ ["children", Access.at(0)]

  test "real serialized page save and persisted fixtures validate with cached concurrent reuse" do
    for {_name, model} <- @models do
      assert :ok = validate(model)
      assert :ok = generic(model)
    end

    root = SchemaResolver.resolve("page-content-adaptive.schema.json")
    assert root == SchemaResolver.resolve("page-content-adaptive.schema.json")

    for result <- Task.async_stream(1..12, fn _ -> validate(@models["persisted"]) end),
        do: assert(result == {:ok, :ok})
  end

  test "page discriminators dispatch deterministically and cannot fall through to Basic Page" do
    model = @models["persisted"]

    for flag <- ~w(advancedAuthoring advancedDelivery) do
      for bad <- [nil, false, "true", 1] do
        assert {:error, [_ | _]} = generic(Map.put(model, flag, bad))
      end

      assert {:error, [_ | _]} = generic(Map.delete(model, flag))
    end

    basic = %{"version" => "0.1.0", "model" => []}
    assert :ok = generic(basic)

    assert :ok =
             generic(
               Map.merge(basic, %{"advancedAuthoring" => false, "advancedDelivery" => false})
             )

    assert {:error, [_ | _]} = generic(Map.put(basic, "advancedAuthoring", "true"))

    malformed =
      Map.merge(basic, %{
        "advancedAuthoring" => true,
        "advancedDelivery" => true,
        "model" => [%{"type" => "content", "children" => []}]
      })

    assert {:error, [_ | _]} = generic(malformed)
    assert :ok = generic(Map.put(model, "version", "0.1.0"))
    assert {:error, [_ | _]} = generic(Map.put(model, "version", "future"))
  end

  test "root structure and optional page settings are strictly typed" do
    model = @models["persisted"]

    for key <- ~w(advancedAuthoring advancedDelivery model),
        do: assert({:error, [_ | _]} = validate(Map.delete(model, key)))

    for {key, bad} <- [
          {"model", %{}},
          {"custom", []},
          {"customCss", nil},
          {"customScript", []},
          {"displayApplicationChrome", "false"},
          {"additionalStylesheets", [1]},
          {"typo", true},
          {"responsiveLayout", true},
          {"resourceAttemptState", %{}}
        ],
        do: assert({:error, [_ | _]} = validate(Map.put(model, key, bad)))

    for bad <- [nil, [], %{}, "page"], do: assert({:error, [_ | _]} = validate(bad))
  end

  test "model contains closed deck groups with flat activity-reference children" do
    model = @models["persisted"]
    group = get_in(model, group_path())

    for key <- ~w(type layout children),
        do:
          assert(
            {:error, [_ | _]} = validate(put_in(model, group_path(), Map.delete(group, key)))
          )

    for {key, bad} <- [
          {"layout", "vertical"},
          {"layout", "unknown"},
          {"children", %{}},
          {"children", [%{"type" => "group", "layout" => "deck", "children" => []}]},
          {"id", []},
          {"typo", true}
        ],
        do: assert({:error, [_ | _]} = validate(put_in(model, group_path() ++ [key], bad)))

    assert :ok = validate(put_in(model, group_path() ++ ["id"], "legacy-deck"))
    assert :ok = validate(put_in(model, group_path() ++ ["children"], []))
    assert :ok = validate(Map.put(model, "model", []))
    assert :ok = validate(Map.put(model, "model", [group, group]))
  end

  test "reference target forms are typed without validating existence or cross-field agreement" do
    model = @models["persisted"]
    reference = get_in(model, ref_path())

    for {key, value} <- [
          {"activity_id", 123},
          {"activity_id", "export-id"},
          {"activityId", "legacy-id"},
          {"activityId", 123},
          {"activitySlug", "revision-slug"}
        ] do
      updated =
        reference |> Map.drop(~w(activity_id activityId activitySlug)) |> Map.put(key, value)

      assert :ok = validate(put_in(model, ref_path(), updated))
      assert {:error, [_ | _]} = validate(put_in(model, ref_path(), Map.delete(updated, key)))
    end

    for {key, bad} <- [
          {"activity_id", nil},
          {"activitySlug", 123},
          {"id", []},
          {"custom", nil},
          {"resourceId", 123},
          {"children", []},
          {"typo", true}
        ],
        do: assert({:error, [_ | _]} = validate(put_in(model, ref_path() ++ [key], bad)))

    assert :ok =
             validate(
               put_in(model, ref_path(), Map.put(reference, "activitySlug", "missing-revision"))
             )

    # The Seeder/legacy export form has no custom sequence metadata.
    legacy = %{"type" => "activity-reference", "activity_id" => 123}
    assert :ok = validate(put_in(model, ref_path(), legacy))
    assert :ok = validate(Oli.Seeder.create_sample_adaptive_page_content(123))
  end

  test "sequence metadata supports layers, banks and legacy null parent pointers" do
    model = @models["persisted"]
    path = ref_path() ++ ["custom"]
    custom = get_in(model, path)

    for key <- ~w(sequenceId sequenceName),
        do: assert({:error, [_ | _]} = validate(put_in(model, path, Map.delete(custom, key))))

    for {key, bad} <- [
          {"sequenceId", 1},
          {"sequenceName", nil},
          {"layerRef", 1},
          {"isBank", "false"},
          {"isLayer", "true"},
          {"bankShowCount", "2"},
          {"bankEndTarget", 1},
          {"sequenceID", "typo"}
        ],
        do: assert({:error, [_ | _]} = validate(put_in(model, path ++ [key], bad)))

    assert :ok = validate(put_in(model, path ++ ["layerRef"], nil))
    assert :ok = validate(put_in(model, path ++ ["layerRef"], "missing-parent"))

    bank =
      Map.merge(custom, %{
        "isBank" => true,
        "bankShowCount" => -1.5,
        "bankEndTarget" => "missing-target"
      })

    assert :ok = validate(put_in(model, path, bank))

    for key <- ~w(bankShowCount bankEndTarget),
        do: assert({:error, [_ | _]} = validate(put_in(model, path, Map.delete(bank, key))))
  end

  test "known lesson settings are typed while opaque legacy extensions are preserved" do
    model = @models["persisted"]

    for {key, bad} <- [
          {"defaultScreenWidth", "1200"},
          {"defaultScreenHeight", nil},
          {"totalScore", "1"},
          {"maxScore", []},
          {"responsiveLayout", "true"},
          {"enableHistory", "false"},
          {"scoreFixed", 1},
          {"themeId", 123},
          {"variables", %{}},
          {"everApps", nil}
        ],
        do: assert({:error, [_ | _]} = validate(put_in(model, ["custom", key], bad)))

    for key <-
          ~w(contentMode themeId viewerSkin logoutMessage logoutPanelImageURL backgroundImageURL),
        do: assert(:ok = validate(put_in(model, ["custom", key], "uninterpreted string")))

    assert :ok = validate(put_in(model, ["custom", "totalScore"], -2.5))

    assert :ok =
             validate(
               put_in(model, ["custom", "futureIntegration"], %{
                 "mathExpression" => [%{"unknown" => true}],
                 "$ref" => "data-only"
               })
             )

    assert :ok = validate(Map.delete(model, "custom"))
  end

  test "variables and EverApps have typed closed wrappers without expression or URL evaluation" do
    model = @models["persisted"]
    variables = [%{"name" => "x", "expression" => "unparsed expression {"}, %{}]
    assert :ok = validate(put_in(model, ["custom", "variables"], variables))

    for bad <- [
          %{"name" => 1},
          %{"expression" => []},
          %{"name" => "x", "expression" => "1", "typo" => true}
        ],
        do: assert({:error, [_ | _]} = validate(put_in(model, ["custom", "variables"], [bad])))

    app = %{
      "id" => "app",
      "name" => "Application",
      "url" => "relative-url",
      "iconUrl" => "icon",
      "isVisible" => true
    }

    assert :ok = validate(put_in(model, ["custom", "everApps"], [app]))

    for key <- Map.keys(app),
        do:
          assert(
            {:error, [_ | _]} =
              validate(put_in(model, ["custom", "everApps"], [Map.delete(app, key)]))
          )

    assert {:error, [_ | _]} =
             validate(put_in(model, ["custom", "everApps"], [Map.put(app, "typo", true)]))
  end

  test "Adaptive export reuses generic Page validation and closes only the Adaptive envelope" do
    root = SchemaResolver.resolve("adaptive-page.schema.json")
    generic_root = SchemaResolver.resolve("page.schema.json")

    export = %{
      "id" => "page",
      "type" => "Page",
      "title" => "Adaptive",
      "isGraded" => false,
      "objectives" => %{"attached" => []},
      "tags" => [],
      "content" => @models["persisted"]
    }

    assert :ok = JSONValidation.validate(root, export)
    assert :ok = JSONValidation.validate(generic_root, export)

    for bad <- [
          Map.put(export, "type", "Activity"),
          Map.put(export, "typo", true),
          Map.delete(export, "title"),
          Map.put(export, "content", %{"version" => "0.1.0", "model" => []})
        ],
        do: assert({:error, [_ | _]} = JSONValidation.validate(root, bad))
  end
end
