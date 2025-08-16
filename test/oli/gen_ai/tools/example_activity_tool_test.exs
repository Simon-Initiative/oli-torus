defmodule Oli.GenAI.Tools.ExampleActivityToolTest do
  use ExUnit.Case, async: true

  alias Oli.GenAI.Tools.ExampleActivityTool

  describe "example activity tool" do
    test "returns multiple choice example" do
      frame = %{}
      result = ExampleActivityTool.execute(%{activity_type: "oli_multiple_choice"}, frame)

      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => json_text}] = response.content

      {:ok, activity} = Jason.decode(json_text)

      assert {:ok, _} = Oli.Validation.validate_activity(activity)

      assert Map.has_key?(activity, "stem")
      assert Map.has_key?(activity, "choices")
      assert Map.has_key?(activity, "authoring")
      assert activity["stem"]["content"] |> hd() |> get_in(["children"]) |> hd() |> Map.get("text") == "What is the capital of France?"
      assert length(activity["choices"]) >= 2
    end

    test "returns short answer example" do
      frame = %{}
      result = ExampleActivityTool.execute(%{activity_type: "oli_short_answer"}, frame)

      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => json_text}] = response.content

      {:ok, _activity} = Jason.decode(json_text)

      {:ok, activity} = Jason.decode(json_text)
      assert Map.has_key?(activity, "stem")
      assert Map.has_key?(activity, "inputType")
      assert Map.has_key?(activity, "authoring")
      assert activity["inputType"] == "text"
    end

    test "returns check all that apply example" do
      frame = %{}
      result = ExampleActivityTool.execute(%{activity_type: "oli_check_all_that_apply"}, frame)

      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => json_text}] = response.content

      {:ok, _activity} = Jason.decode(json_text)

      {:ok, activity} = Jason.decode(json_text)
      assert Map.has_key?(activity, "stem")
      assert Map.has_key?(activity, "choices")
      assert Map.has_key?(activity, "authoring")
      assert length(activity["choices"]) > 2
      assert Map.has_key?(activity["authoring"], "correct")
    end

    test "returns likert example" do
      frame = %{}
      result = ExampleActivityTool.execute(%{activity_type: "oli_likert"}, frame)

      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => json_text}] = response.content

      {:ok, _activity} = Jason.decode(json_text)

      {:ok, activity} = Jason.decode(json_text)
      assert Map.has_key?(activity, "stem")
      assert Map.has_key?(activity, "choices")
      assert Map.has_key?(activity, "items")
      assert Map.has_key?(activity, "authoring")
      assert is_list(activity["items"])
      assert is_list(activity["choices"])
    end

    test "returns multi input example" do
      frame = %{}
      result = ExampleActivityTool.execute(%{activity_type: "oli_multi_input"}, frame)

      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => json_text}] = response.content

      {:ok, _activity} = Jason.decode(json_text)

      {:ok, activity} = Jason.decode(json_text)
      assert Map.has_key?(activity, "stem")
      assert Map.has_key?(activity, "inputs")
      assert Map.has_key?(activity, "authoring")
      assert is_list(activity["inputs"])
    end

    test "returns ordering example" do
      frame = %{}
      result = ExampleActivityTool.execute(%{activity_type: "oli_ordering"}, frame)

      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => json_text}] = response.content

      {:ok, _activity} = Jason.decode(json_text)

      {:ok, activity} = Jason.decode(json_text)
      assert Map.has_key?(activity, "stem")
      assert Map.has_key?(activity, "choices")
      assert Map.has_key?(activity, "authoring")
      assert length(activity["choices"]) >= 2
      assert Map.has_key?(activity["authoring"], "correct")
    end

    test "returns error for unknown activity type" do
      frame = %{}
      result = ExampleActivityTool.execute(%{activity_type: "unknown_type"}, frame)

      assert {:reply, response, ^frame} = result
      assert response.isError == true
      assert [%{"type" => "text", "text" => error_text}] = response.content
      assert String.contains?(error_text, "Unknown activity type")
      assert String.contains?(error_text, "unknown_type")
    end

    test "includes all supported activity types in error message" do
      frame = %{}
      result = ExampleActivityTool.execute(%{activity_type: "invalid"}, frame)

      assert {:reply, response, ^frame} = result
      assert response.isError == true
      assert [%{"type" => "text", "text" => error_text}] = response.content

      # Should mention all supported types
      assert String.contains?(error_text, "oli_multiple_choice")
      assert String.contains?(error_text, "oli_short_answer")
      assert String.contains?(error_text, "oli_check_all_that_apply")
      assert String.contains?(error_text, "oli_likert")
      assert String.contains?(error_text, "oli_multi_input")
      assert String.contains?(error_text, "oli_ordering")
    end
  end
end
