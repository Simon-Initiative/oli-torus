defmodule Oli.GoogleDocs.McqBuilderTest do
  use ExUnit.Case, async: true

  alias Oli.GoogleDocs.CustomElements
  alias Oli.GoogleDocs.CustomElements.Mcq
  alias Oli.GoogleDocs.CustomElements.Mcq.Choice
  alias Oli.GoogleDocs.MarkdownParser
  alias Oli.GoogleDocs.McqBuilder
  alias Oli.GoogleDocsImport.TestHelpers

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
            id: 101,
            resource_id: 202,
            slug: "mcq-#{title || "untitled"}",
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

  defp mcq_fixture do
    fixture = TestHelpers.load_fixture(:custom_elements)

    {:ok, parsed} =
      MarkdownParser.parse(fixture.body, metadata: fixture.metadata)

    {:ok, result} = CustomElements.resolve(parsed.custom_elements)
    Map.fetch!(result.elements, "custom-element-2")
  end

  test "build/2 creates an activity model and delegates to the activity editor" do
    mcq = mcq_fixture()

    assert {:ok, result} =
             McqBuilder.build(mcq,
               project_slug: "project-slug",
               author: %{id: 1},
               activity_editor: StubActivityEditor
             )

    assert result.mcq == mcq
    assert length(result.model["choices"]) == 3

    Enum.each(result.model["choices"], fn choice ->
      assert choice["editor"] == "slate"
      assert is_list(choice["content"])
    end)

    part = hd(result.model["authoring"]["parts"])
    assert part["scoringStrategy"] == "best"

    responses = part["responses"]
    assert Enum.any?(responses, &(&1["score"] == 1.0))
    assert Enum.all?(responses, fn r -> r["score"] in [1.0, 0.0] end)
    assert List.last(responses)["rule"] == "input like {.*}"
    assert List.last(responses)["score"] == 0.0
    assert Enum.all?(responses, fn r -> r["feedback"]["editor"] == "slate" end)

    targeted = result.model["authoring"]["targeted"]
    assert length(targeted) == 2
    targeted_map =
      targeted
      |> Enum.map(fn [choice_ids, response_id] -> {List.first(choice_ids), response_id} end)
      |> Enum.into(%{})

    incorrect_responses = Enum.filter(responses, &(&1["score"] == 0.0))
    Enum.each(incorrect_responses, fn response ->
      expected_choice =
        case response["rule"] do
          "input like {" <> rest -> String.trim_trailing(rest, "}")
          _ -> nil
        end

      if expected_choice && Map.has_key?(targeted_map, expected_choice) do
        assert targeted_map[expected_choice] == response["id"]
      else
        assert response["rule"] == "input like {.*}"
      end
    end)

    hints = part["hints"]
    assert length(hints) == 3
    assert Enum.all?(hints, &(&1["editor"] == "slate"))

    refute Enum.any?(result.warnings, &match?(%{code: :mcq_feedback_missing}, &1))

    assert [
             %{
               project_slug: "project-slug",
               scope: "embedded",
               title: title
             }
           ] = StubActivityEditor.calls()

    assert is_binary(title)
    assert title != ""
  end

  test "returns warnings and success when optional feedback is missing" do
    mcq =
      mcq_fixture()
      |> Map.update!(:choices, fn choices ->
        Enum.map(choices, fn
          %Choice{id: "choice2"} = choice -> %Choice{choice | feedback: nil, feedback_key: nil}
          other -> other
        end)
      end)

    assert {:ok, result} =
             McqBuilder.build(mcq,
               project_slug: "project-slug",
               author: %{id: 1},
               activity_editor: StubActivityEditor
             )

    assert Enum.any?(result.warnings, &(&1.code == :mcq_feedback_missing))

    responses =
      result.model["authoring"]["parts"]
      |> hd()
      |> Map.fetch!("responses")

    assert Enum.any?(responses, fn response ->
             response["feedback"]["content"] == [] and response["feedback"]["editor"] == "slate"
           end)
  end

  test "drops blank choices and emits warnings" do
    mcq =
      mcq_fixture()
      |> Map.update!(:choices, fn choices ->
        Enum.map(choices, fn
          %Choice{id: "choice3"} = choice -> %Choice{choice | text: " "}
          other -> other
        end)
      end)

    assert {:ok, result} =
             McqBuilder.build(mcq,
               project_slug: "project-slug",
               author: %{id: 1},
               activity_editor: StubActivityEditor
             )

    assert Enum.any?(result.warnings, &(&1.code == :mcq_choice_missing))
    assert length(result.model["choices"]) == 2
  end

  test "returns error when correct key is missing or invalid" do
    mcq = %Mcq{mcq_fixture() | correct_key: nil}

    assert {:error, :missing_correct, warnings} =
             McqBuilder.build(mcq,
               project_slug: "project-slug",
               author: %{id: 1},
               activity_editor: StubActivityEditor
             )

    assert Enum.any?(warnings, &(&1.code == :mcq_missing_correct))
    assert StubActivityEditor.calls() == []
  end

  test "returns error when activity editor fails" do
    mcq = mcq_fixture()
    StubActivityEditor.set_response({:error, :not_authorized})

    assert {:error, :activity_creation_failed, warnings} =
             McqBuilder.build(mcq,
               project_slug: "project-slug",
               author: %{id: 1},
               activity_editor: StubActivityEditor
             )

    assert Enum.any?(warnings, &(&1.code == :mcq_activity_creation_failed))
  end
end
