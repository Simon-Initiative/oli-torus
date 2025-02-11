defmodule Oli.Conversation.TriggersTest do
  use ExUnit.Case, async: true

  alias Oli.Conversation.Triggers
  alias Oli.Activities.Model.Part

  test "response correct" do
    relevant_triggers_by_type =
      Triggers.relevant_triggers_by_type(%Part{
        id: "part_id",
        triggers: [
          %Oli.Activities.Model.Trigger{
            id: "trigger_id1",
            trigger_type: :correct_answer,
            prompt: "correct prompt",
            ref_id: 1
          }
        ]
      })

    response = %{
      id: "1",
      score: 2.0
    }

    context = %{
      activity_attempt_guid: "attempt_guid",
      page_id: 23
    }

    trigger =
      Triggers.check_for_response_trigger(relevant_triggers_by_type, response, 2.0, context)

    assert trigger.prompt == "correct prompt"
    assert trigger.trigger_type == :correct_answer
  end

  test "response incorrect" do
    relevant_triggers_by_type =
      Triggers.relevant_triggers_by_type(%Part{
        id: "part_id",
        triggers: [
          %Oli.Activities.Model.Trigger{
            id: "trigger_id1",
            trigger_type: :correct_answer,
            prompt: "correct prompt",
            ref_id: nil
          },
          %Oli.Activities.Model.Trigger{
            id: "trigger_id2",
            trigger_type: :incorrect_answer,
            prompt: "incorrect prompt",
            ref_id: nil
          }
        ]
      })

    response = %{
      id: "3",
      score: 1.0
    }

    context = %{
      activity_attempt_guid: "attempt_guid",
      page_id: 23
    }

    trigger =
      Triggers.check_for_response_trigger(relevant_triggers_by_type, response, 2.0, context)

    assert trigger.prompt == "incorrect prompt"
    assert trigger.trigger_type == :incorrect_answer
  end

  test "response targeted AND correct" do
    relevant_triggers_by_type =
      Triggers.relevant_triggers_by_type(%Part{
        id: "part_id",
        triggers: [
          %Oli.Activities.Model.Trigger{
            id: "trigger_id1",
            trigger_type: :correct_answer,
            prompt: "correct prompt",
            ref_id: nil
          },
          %Oli.Activities.Model.Trigger{
            id: "trigger_id1",
            trigger_type: :targeted_feedback,
            prompt: "targeted prompt",
            ref_id: "2"
          }
        ]
      })

    response = %{
      id: "2",
      score: 2.0
    }

    context = %{
      activity_attempt_guid: "attempt_guid",
      page_id: 23
    }

    trigger =
      Triggers.check_for_response_trigger(relevant_triggers_by_type, response, 2.0, context)

    assert trigger.prompt == "targeted prompt"
    assert trigger.trigger_type == :targeted_feedback
  end

  test "explanation" do
    part = %{
      id: "part_id",
      triggers: [
        %Oli.Activities.Model.Trigger{
          id: "trigger_id1",
          trigger_type: :explanation,
          prompt: "explanation prompt",
          ref_id: 1
        }
      ]
    }

    explanation = %{
      id: "explanation_id"
    }

    explanation_context = %{
      activity_attempt: %{
        attempt_guid: "attempt_guid"
      },
      resource_revision: %{
        resource_id: "resource_id"
      }
    }

    trigger = Triggers.check_for_explanation_trigger(part, explanation, explanation_context)
    assert trigger.data["ref_id"] == "explanation_id"
  end

  test "check hint trigger" do
    activity_attempt = %{
      resource_id: "activity_id"
    }

    part_attempt = %{
      part_id: "part_id"
    }

    model = %{
      parts: [
        %{
          id: "part_id",
          hints: [
            %{
              id: "hint_id",
              content: "this is the hint"
            }
          ],
          triggers: [
            %Oli.Activities.Model.Trigger{
              id: "trigger_id1",
              trigger_type: :hint_request,
              prompt: "hint prompt",
              ref_id: 1
            }
          ]
        }
      ]
    }

    hint = %{
      id: "hint_id",
      hint: "this is the hint"
    }

    trigger = Triggers.check_for_hint_trigger(activity_attempt, part_attempt, model, hint)

    assert trigger.data["ref_id"] == 1
    assert trigger.prompt == "hint prompt"
  end

  test "check for hint trigger when multiple present" do
    activity_attempt = %{
      resource_id: "activity_id"
    }

    part_attempt = %{
      part_id: "part_id"
    }

    model = %{
      parts: [
        %{
          id: "part_id",
          hints: [
            %{
              id: "hint_id1",
              content: "this is the hint1"
            },
            %{
              id: "hint_id2",
              content: "this is the hint2"
            },
            %{
              id: "hint_id3",
              content: "this is the hint3"
            }
          ],
          triggers: [
            %{
              trigger_type: :hint_request,
              prompt: "hint prompt",
              ref_id: 3
            }
          ]
        }
      ]
    }

    hint = %{
      id: "hint_id3",
      hint: "this is the hint"
    }

    trigger = Triggers.check_for_hint_trigger(activity_attempt, part_attempt, model, hint)

    assert trigger.data["ref_id"] == 3
    assert trigger.prompt == "hint prompt"

    hint = %{
      id: "hint_id1",
      hint: "this is the hint1"
    }

    trigger = Triggers.check_for_hint_trigger(activity_attempt, part_attempt, model, hint)
    assert is_nil(trigger)
  end
end
