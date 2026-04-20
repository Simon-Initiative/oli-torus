defmodule Oli.InstructorDashboard.Recommendations.PromptTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Recommendations.Prompt

  describe "build_messages/2" do
    test "builds versioned system and user messages with dataset sections" do
      [system_message, user_message] = Prompt.build_messages(input_contract_fixture())

      assert system_message.role == :system
      assert user_message.role == :user
      assert system_message.content =~ "expert learning engineer and instructor dashboard analyst"
      assert system_message.content =~ "Produce one instructional insight or recommendation total"
      assert user_message.content =~ "Prompt version: recommendation_prompt_v1"
      assert user_message.content =~ "### What you have"
      assert user_message.content =~ "### Output requirements"
      assert user_message.content =~ "Dataset: scope_overview"

      assert user_message.content =~
               "| course_title | scope_label | scope_type | items_in_scope | titles_preview |"

      assert user_message.content =~ "Produce the final recommendation now."
    end

    test "adds explicit no-signal guidance when the input contract is no-signal" do
      [system_message, user_message] =
        Prompt.build_messages(
          put_in(input_contract_fixture(), [:signal_summary, :state], :no_signal)
          |> put_in([:signal_summary, :reasons], [:no_students, :no_activity_data])
        )

      assert system_message.content =~ "signal_state=no_signal"
      assert system_message.content =~ "Return exactly one sentence"
      assert user_message.content =~ "No-signal reasons: no_students, no_activity_data"
    end
  end

  defp input_contract_fixture do
    %{
      prompt_version: Prompt.version(),
      signal_summary: %{
        state: :ready,
        reasons: [],
        total_students: 10,
        has_activity_data?: true,
        has_assessment_signal?: true
      },
      scope: %{
        course_title: "Intro to Testing",
        scope_label: "Entire Course",
        container_type: :course,
        container_id: nil
      },
      datasets: [
        %{
          key: :scope_overview,
          descriptor: "Scope overview",
          columns: [
            "course_title",
            "scope_label",
            "scope_type",
            "items_in_scope",
            "titles_preview"
          ],
          rows: [["Intro to Testing", "Entire Course", "course", 3, "Unit 1 | Unit 2"]]
        }
      ]
    }
  end
end
