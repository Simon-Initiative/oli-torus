defmodule Oli.GoogleDocs.DropdownBuilderTest do
  use ExUnit.Case, async: true

  alias Oli.GoogleDocs.CustomElements.Dropdown
  alias Oli.GoogleDocs.DropdownBuilder

  defmodule StubActivityEditor do
    @moduledoc false

    def reset do
      Process.put(state_key(), %{response: :ok, calls: []})
    end

    def set_response(response) do
      state = Process.get(state_key(), %{response: :ok, calls: []})
      Process.put(state_key(), %{state | response: response})
    end

    def calls do
      Process.get(state_key(), %{response: :ok, calls: []}).calls |> Enum.reverse()
    end

    def create(project_slug, type, author, model, objectives, scope \\ "embedded", title \\ nil) do
      state = Process.get(state_key(), %{response: :ok, calls: []})

      Process.put(state_key(), %{
        state
        | calls: [
            %{
              project_slug: project_slug,
              type: type,
              author: author,
              model: model,
              objectives: objectives,
              scope: scope,
              title: title
            }
            | state.calls
          ]
      })

      case state.response do
        :ok ->
          revision = %{
            id: 501,
            resource_id: 601,
            slug: "dropdown-#{title || "untitled"}",
            content: model
          }

          {:ok, {revision, nil}}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp state_key, do: {__MODULE__, self()}
  end

  setup do
    StubActivityEditor.reset()
    :ok
  end

  test "build/2 creates a multi-input dropdown activity" do
    dropdown = dropdown_fixture()

    assert {:ok, result} =
             DropdownBuilder.build(dropdown,
               project_slug: "project-slug",
               author: %{id: 1},
               activity_editor: StubActivityEditor
             )

    assert length(result.model["inputs"]) == 2
    assert Enum.all?(result.model["inputs"], &(&1["inputType"] == "dropdown"))

    stem_nodes = get_in(result.model, ["stem", "content"])
    assert contains_input_ref?(stem_nodes, "dropdown1")
    assert contains_input_ref?(stem_nodes, "dropdown2")

    part_ids = Enum.map(result.model["authoring"]["parts"], & &1["id"])
    assert Enum.sort(part_ids) == ["dropdown1", "dropdown2"]

    choices = Enum.map(result.model["choices"], & &1["id"])
    assert "dropdown1_choice1" in choices
    assert "dropdown2_choice2" in choices

    dropdown1_part = Enum.find(result.model["authoring"]["parts"], &(&1["id"] == "dropdown1"))
    assert dropdown1_part

    correct_rule = "input like {dropdown1_choice1}"
    responses = dropdown1_part["responses"]
    assert Enum.any?(responses, &(&1["rule"] == correct_rule && &1["score"] == 1.0))
    assert List.last(responses)["rule"] == "input like {.*}"

    hints = dropdown1_part["hints"]
    assert length(hints) == 3

    refute Enum.empty?(result.model["authoring"]["targeted"])

    assert [%{project_slug: "project-slug", type: "oli_multi_input"}] = StubActivityEditor.calls()
    assert result.warnings == []
  end

  test "build/2 surfaces warnings when feedback is missing" do
    dropdown = dropdown_fixture(feedback_missing?: true)

    assert {:ok, result} =
             DropdownBuilder.build(dropdown,
               project_slug: "project-slug",
               author: %{id: 1},
               activity_editor: StubActivityEditor
             )

    assert Enum.any?(result.warnings, &(&1.code == :dropdown_feedback_missing))
  end

  test "build/2 returns error when dropdown data is missing" do
    dropdown = dropdown_fixture() |> Map.update!(:data_by_input, &Map.delete(&1, "dropdown2"))

    assert {:error, :missing_input_data, warnings} =
             DropdownBuilder.build(dropdown,
               project_slug: "project-slug",
               author: %{id: 1},
               activity_editor: StubActivityEditor
             )

    assert Enum.any?(warnings, &(&1.code == :dropdown_missing_input_data))
  end

  defp dropdown_fixture(opts \\ []) do
    missing_feedback? = Keyword.get(opts, :feedback_missing?, false)

    %Dropdown{
      id: "custom-element-dropdown",
      block_index: 0,
      stem: "A [dropdown1] and [dropdown2] example.",
      inputs: ["dropdown1", "dropdown2"],
      data_by_input: %{
        "dropdown1" => %{
          "choice1" => "Dog",
          "feedback1" => if(missing_feedback?, do: "", else: "Correct!"),
          "choice2" => "Computer",
          "feedback2" => "Incorrect.",
          "correct" => "choice1",
          "hint1" => "Which choice needs food?"
        },
        "dropdown2" => %{
          "choice1" => "Cat",
          "feedback1" => "Correct again!",
          "choice2" => "Tree",
          "feedback2" => "No.",
          "correct" => "choice1",
          "hint1" => "Animals move."
        }
      },
      raw_rows: []
    }
  end

  defp contains_input_ref?(nodes, id) when is_list(nodes) do
    Enum.any?(nodes, &contains_input_ref?(&1, id))
  end

  defp contains_input_ref?(%{"type" => "input_ref", "id" => ref_id}, id) do
    ref_id == id
  end

  defp contains_input_ref?(%{"children" => children}, id) do
    contains_input_ref?(children, id)
  end

  defp contains_input_ref?(_, _), do: false
end
