defmodule Oli.Analytics.Datashop do
  @moduledoc """
  For documentation on DataShop logging message formats, see:

  https://pslcdatashop.web.cmu.edu/dtd/guide/tutor_message_dtd_guide_v4.pdf
  https://pslcdatashop.web.cmu.edu/help?page=logging
  https://pslcdatashop.web.cmu.edu/help?page=importFormatTd
  """

  import XmlBuilder
  alias Oli.Publishing
  alias Oli.Authoring.Course
  alias Oli.Delivery.Attempts
  alias Oli.Analytics.Datashop.Messages.{Context, Tool, Tutor}
  alias Oli.Analytics.Datashop.Utils

  def export(project_id) do
    project_id
    |> create_messages
    |> wrap_with_tutor_related_message
    |> document
    |> generate
  end

  defp create_messages(project_id) do
    project = Course.get_project!(project_id)
    publication = Publishing.get_latest_published_publication_by_slug!(project.slug)
    dataset_name = Utils.make_dataset_name(project.slug)

    Attempts.get_part_attempts_and_users_for_publication(publication.id)
    |> group_part_attempts_by_user_and_part
    |> Enum.map(fn {{email, activity_slug, part_id}, part_attempts} ->

      context_message_id = Utils.make_unique_id(activity_slug, part_id)
      problem_name = Utils.make_problem_name(activity_slug, part_id)

      context_message = Context.setup(%{
        name: "START_PROBLEM",
        context_message_id: context_message_id,
        meta_element_context: %{
          date: hd(part_attempts).activity_attempt.resource_attempt.inserted_at,
          email: email
        },
        dataset_element_context: %{
          dataset_name: dataset_name,
          part_attempt: hd(part_attempts),
          publication: publication,
          problem_name: problem_name
        }
      })

      pairs = part_attempts
      |> Enum.flat_map(
        fn part_attempt ->

          # The part should be able to be found assuming that it adheres to OLI's activity authoring model
          # If it's a third-party custom activity, the part might not be under the authoring key
          part = part_attempt.activity_attempt.transformed_model["authoring"]["parts"]
          |> Enum.find(%{}, & &1["id"] == part_attempt.part_id)
          skill_ids = part_attempt.activity_attempt.revision.objectives[part_attempt.part_id] || []
          meta_element_context = %{
            date: part_attempt.inserted_at,
            email: email
          }

          hint_message_pairs = part_attempt.hints
          |> Enum.with_index()
          |> Enum.flat_map(
            fn {hint_id, hint_index} ->

              # transaction id connects tool and tutor messages
              transaction_id = Utils.make_unique_id(activity_slug, part_id)

              [
                Tool.setup(%{
                  type: "HINT",
                  context_message_id: context_message_id,
                  meta_element_context: meta_element_context,
                  semantic_event_context: %{
                    transaction_id: transaction_id,
                    name: "HINT_REQUEST"
                  },
                  part_attempt: part_attempt,
                  problem_name: problem_name,
                }),
                Tutor.setup(%{
                  type: "HINT_MSG",
                  context_message_id: context_message_id,
                  transaction_id: transaction_id,
                  meta_element_context: meta_element_context,
                  action_evaluation_context: %{
                    current_hint_number: hint_index + 1,
                    total_hints_available: Utils.total_hints_available(part)
                  },
                  skill_context: %{
                    publication: publication,
                    skill_ids: skill_ids
                  },
                  problem_name: problem_name,
                  part_attempt: part_attempt,
                  hint_text: Utils.hint_text(part, hint_id)
                })
              ]
            end)

          transaction_id = Utils.make_unique_id(activity_slug, part_id)

          hint_message_pairs ++ [
            Tool.setup(%{
              type: "ATTEMPT",
              context_message_id: context_message_id,
              meta_element_context: meta_element_context,
              semantic_event_context: %{
                transaction_id: transaction_id,
                name: "ATTEMPT"
              },
              part_attempt: part_attempt,
              problem_name: problem_name,
            }),
            Tutor.setup(%{
              type: "RESULT",
              context_message_id: context_message_id,
              transaction_id: transaction_id,
              meta_element_context: meta_element_context,
              action_evaluation_context: %{
                part_attempt: part_attempt
              },
              skill_context: %{
                publication: publication,
                skill_ids: skill_ids
              },
              problem_name: problem_name,
              part_attempt: part_attempt,
            })
          ]
        end)
        [context_message | pairs]
    end)
  end

  defp group_part_attempts_by_user_and_part(part_attempts_and_users) do
    part_attempts_and_users
    |> Enum.group_by(
      & {&1.user.email, &1.part_attempt.activity_attempt.revision.slug, &1.part_attempt.part_id},
      & &1.part_attempt)
  end


  # Wraps the messages inside a <tutor_related_message_sequence />, which is required by the
  # Datashop DTD to set the meta-info.
  defp wrap_with_tutor_related_message(children) do
    element(:tutor_related_message_sequence,
      %{
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:noNamespaceSchemaLocation" => "http://pslcdatashop.org/dtd/tutor_message_v4.xsd",
        "version_number" => "4"
      },
      children)
  end
end
