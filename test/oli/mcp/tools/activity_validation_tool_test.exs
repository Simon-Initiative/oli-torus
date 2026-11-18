defmodule Oli.MCP.Tools.ActivityValidationToolTest do
  use ExUnit.Case, async: true
  alias Oli.MCP.Tools.ActivityValidationTool
  @model "test/support/fixtures/multiple_choice_model.json" |> File.read!() |> Jason.decode!()

  test "validates an explicit Basic Page type through both stages" do
    assert {:reply, response, %{}} =
             ActivityValidationTool.execute(
               %{activity_json: Jason.encode!(@model), activity_type_slug: "oli_multiple_choice"},
               %{}
             )

    assert response.content == [%{"type" => "text", "text" => "Activity JSON is valid"}]
    refute response.isError
  end

  test "returns structured stage-specific errors without conflating schema and domain" do
    bad_rule =
      put_in(
        @model,
        ["authoring", "parts", Access.at(0), "responses", Access.at(0), "rule"],
        "invalid"
      )

    for {stage, json} <- [
          {"json", "{ invalid json"},
          {"schema", Jason.encode!(Map.delete(@model, "stem"))},
          {"domain", Jason.encode!(bad_rule)}
        ] do
      assert {:reply, response, %{}} =
               ActivityValidationTool.execute(
                 %{activity_json: json, activity_type_slug: "oli_multiple_choice"},
                 %{}
               )

      assert response.isError
      assert response.structured_content.stage == stage
      assert [%{path: _, code: _, message: _} | _] = response.structured_content.errors
      assert [%{"text" => text}] = response.content
      assert text =~ "Validation failed"
    end
  end

  test "does not guess an activity type" do
    assert {:reply, response, %{}} =
             ActivityValidationTool.execute(%{activity_json: Jason.encode!(@model)}, %{})

    assert response.isError
    assert response.structured_content.stage == "schema"
    assert hd(response.structured_content.errors).code == "unsupported_activity_type"
  end
end
