defmodule Oli.GenAI.Completions.FunctionTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Completions.Function

  def echo_arguments(arguments), do: arguments

  test "trusted arguments override model supplied values" do
    available_functions = [
      %{
        name: "echo_arguments",
        full_name: "Elixir.Oli.GenAI.Completions.FunctionTest.echo_arguments",
        trusted_arguments: %{"section_id" => 42, "current_user_id" => 7}
      }
    ]

    assert {:ok, encoded_result} =
             Function.call(available_functions, "echo_arguments", %{
               "section_id" => 999,
               "current_user_id" => 888,
               "activity_attempt_guid" => "attempt-guid-1"
             })

    assert Jason.decode!(encoded_result) == %{
             "section_id" => 42,
             "current_user_id" => 7,
             "activity_attempt_guid" => "attempt-guid-1"
           }
  end
end
