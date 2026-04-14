defmodule Oli.InstructorDashboard.Recommendations.PayloadTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Recommendations.Payload

  describe "normalize/1" do
    test "keeps only sanctioned metadata keys" do
      payload =
        Payload.normalize(%{
          id: 10,
          section_id: 20,
          container_type: :course,
          container_id: nil,
          state: :ready,
          message: "Recommendation text",
          generated_at: ~U[2026-04-10 12:00:00Z],
          generation_mode: :implicit,
          feedback_summary: %{sentiment_submitted?: false},
          metadata: %{
            fallback_reason: nil,
            prompt_version: "recommendation_prompt_v1",
            provider_usage: %{tokens: 123},
            student_email: "ada@example.edu",
            raw_prompt: "sensitive"
          }
        })

      assert payload.metadata == %{
               fallback_reason: nil,
               prompt_version: "recommendation_prompt_v1",
               provider_usage: %{tokens: 123}
             }
    end
  end
end
