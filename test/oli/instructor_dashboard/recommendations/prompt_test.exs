defmodule Oli.InstructorDashboard.Recommendations.PromptTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Recommendations.Prompt

  describe "build_messages/2" do
    test "builds a single rendered system prompt with interpolated datasets" do
      [system_message, user_message] = Prompt.build_messages(input_contract_fixture())

      assert system_message.role == :system
      assert user_message.role == :user
      assert system_message.content =~ "expert learning engineer and instructor dashboard analyst"
      assert system_message.content =~ "### What you have"
      assert system_message.content =~ "Descriptor: Scope overview"

      assert system_message.content =~
               "| course_title | scope_label | scope_type | items_in_scope | titles_preview |"

      refute system_message.content =~ "\#{data}"
      assert user_message.content == "Begin now."
    end

    test "adds explicit no-signal guidance when the input contract is no-signal" do
      [system_message, user_message] =
        Prompt.build_messages(
          put_in(input_contract_fixture(), [:signal_summary, :state], :no_signal)
          |> put_in([:signal_summary, :reasons], [:no_students, :no_activity_data])
        )

      assert system_message.content =~ "signal_state=no_signal"
      assert system_message.content =~ "Return exactly one sentence"
      assert user_message.content == "Begin now."
    end

    test "uses a custom prompt template and interpolates datasets when placeholder is present" do
      [system_message, _user_message] =
        Prompt.build_messages(input_contract_fixture(),
          prompt_template: "Custom header\n\n\#{data}\n\nCustom footer"
        )

      assert system_message.content =~ "Custom header"
      assert system_message.content =~ "Descriptor: Scope overview"
      assert system_message.content =~ "Custom footer"
      refute system_message.content =~ "\#{data}"
    end

    test "falls back to default prompt template when custom template is blank" do
      [system_message, _user_message] =
        Prompt.build_messages(input_contract_fixture(), prompt_template: "   ")

      assert system_message.content =~
               "You are an expert learning engineer and instructor dashboard analyst."

      assert system_message.content =~ "### What you have"
      assert system_message.content =~ "Descriptor: Scope overview"
      refute system_message.content =~ "\#{data}"
    end

    test "appends datasets at the end when custom template does not include placeholder" do
      [system_message, _user_message] =
        Prompt.build_messages(input_contract_fixture(),
          prompt_template: "Custom recommendation prompt"
        )

      assert system_message.content =~ "Custom recommendation prompt"
      assert system_message.content =~ "Descriptor: Scope overview"
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
