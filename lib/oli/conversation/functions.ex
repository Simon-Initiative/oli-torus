defmodule Oli.Conversation.Functions do

  import Oli.Conversation.Common

  @functions [
    %{
      name: "up_next",
      description:
        "Returns the next scheduled lessons in the course as a list of objects with the following keys: title, url, due_date, num_attempts_taken",
      parameters: %{
        type: "object",
        properties: %{
          current_user_id: %{
            type: "integer",
            description: "The current student's user id"
          },
          section_id: %{
            type: "integer",
            description: "The current course section's id"
          }
        },
        required: ["current_user_id", "section_id"]
      }
    },
    %{
      name: "avg_score_for",
      description:
        "Returns average score across all scored assessments, as a floating point number between 0 and 1, for a given user and section",
      parameters: %{
        type: "object",
        properties: %{
          current_user_id: %{
            type: "integer",
            description: "The current student's user id"
          },
          section_id: %{
            type: "integer",
            description: "The current course section's id"
          }
        },
        required: ["current_user_id", "section_id"]
      }
    },
    %{
      name: "relevant_course_content",
      description: """
      Useful when a question asked by a student cannot be adequately answered by the context of the current lesson.
      Allows the retrieval of relevant course content from other lessons in the course based on the
      student's question. Returns an array of course lessons with the following keys: title, url, content.
      """,
      parameters: %{
        type: "object",
        properties: %{
          student_input: %{
            type: "string",
            description: "The student question or input"
          },
          section_id: %{
            type: "integer",
            description: "The current course section's id"
          }
        },
        required: ["student_input", "section_id"]
      }
    }
  ]

  def functionns, do: @functions

  def total_token_length, do: Enum.reduce(@functions, 0, fn f, acc -> acc + estimate_token_length(f) end)

end
