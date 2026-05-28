defmodule Oli.Activities.ParseTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Model
  alias Oli.Activities.Model.Response
  alias Oli.TestHelpers

  defp feedback(id \\ "feedback-1") do
    %{"id" => id, "content" => %{"model" => []}}
  end

  test "parsing of a valid model" do
    {:ok, contents} = TestHelpers.read_json_file("./test/oli/activities/valid.json")

    assert {:ok, parsed} = Model.parse(contents)

    assert length(parsed.parts) == 2
    assert length(parsed.transformations) == 1
  end

  test "collecting errors" do
    {:ok, contents} = TestHelpers.read_json_file("./test/oli/activities/errors.json")

    assert {:error, errors} = Model.parse(contents)

    assert length(errors) == 4
  end

  test "response parser preserves matchConfig and allows missing rule" do
    match_config = %{"version" => 1, "type" => "always"}

    assert {:ok, %Response{rule: "", match_config: ^match_config}} =
             Response.parse(%{
               "id" => "response-1",
               "matchConfig" => match_config,
               "score" => 1,
               "feedback" => feedback()
             })
  end

  test "response parser keeps legacy rule requirement when matchConfig is absent" do
    assert {:ok, %Response{rule: "input like {.*}", match_config: nil}} =
             Response.parse(%{
               "id" => "response-1",
               "rule" => "input like {.*}",
               "score" => 0,
               "feedback" => feedback()
             })

    assert {:error, "invalid response"} =
             Response.parse(%{
               "id" => "response-1",
               "score" => 0,
               "feedback" => feedback()
             })
  end

  test "short answer parsing annotates parts with top-level input type" do
    assert {:ok, %Model{parts: [part]}} =
             Model.parse(%{
               "inputType" => "math_expression",
               "itemConfig" => %{
                 "version" => 1,
                 "type" => "math_expression",
                 "subtype" => "algebraic",
                 "config" => %{"validation" => %{"allowedVariables" => ["x"]}}
               },
               "authoring" => %{
                 "parts" => [%{"id" => "part-1"}]
               }
             })

    assert part.input_type == "math_expression"

    assert part.item_config == %{
             "version" => 1,
             "type" => "math_expression",
             "subtype" => "algebraic",
             "config" => %{"validation" => %{"allowedVariables" => ["x"]}}
           }
  end

  test "multi input parsing annotates parts from inputs by part id" do
    assert {:ok, %Model{parts: parts}} =
             Model.parse(%{
               "inputs" => [
                 %{"id" => "input-1", "partId" => "part-1", "inputType" => "numeric"},
                 %{
                   "id" => "input-2",
                   "partId" => "part-2",
                   "inputType" => "math_expression",
                   "itemConfig" => %{
                     "version" => 1,
                     "type" => "math_expression",
                     "subtype" => "algebraic",
                     "config" => %{"validation" => %{"allowedVariables" => ["x"]}}
                   }
                 }
               ],
               "authoring" => %{
                 "parts" => [%{"id" => "part-1"}, %{"id" => "part-2"}, %{"id" => "part-3"}]
               }
             })

    assert Enum.map(parts, &{&1.id, &1.input_type}) == [
             {"part-1", "numeric"},
             {"part-2", "math_expression"},
             {"part-3", nil}
           ]

    assert Enum.at(parts, 1).item_config == %{
             "version" => 1,
             "type" => "math_expression",
             "subtype" => "algebraic",
             "config" => %{"validation" => %{"allowedVariables" => ["x"]}}
           }
  end
end
