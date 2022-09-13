defmodule Oli.Analytics.DatashopTest do
  use Oli.DataCase

  import SweetXml

  alias Oli.Seeder
  alias Oli.Utils.Seeder.StudentAttemptSeed
  alias Oli.Analytics.Datashop
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Delivery.Attempts.PageLifecycle.Hierarchy

  describe "datashop export" do
    setup do
      content = %{
        "stem" => "Example MCQ activity. Correct answer is 'Choice A'",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "gradingApproach" => "automatic",
              "scoringStrategy" => "average",
              "responses" => [
                %{
                  "rule" => "input like {3222237681}",
                  "score" => 10,
                  "id" => "r1",
                  "feedback" => %{
                    "id" => "1",
                    "content" => [
                      %{
                        "children" => [
                          %{
                            "text" => "Correct"
                          }
                        ],
                        "id" => "2624267862",
                        "type" => "p"
                      }
                    ]
                  }
                },
                %{
                  "rule" => "input like {1945694347}",
                  "score" => 1,
                  "id" => "r2",
                  "feedback" => %{
                    "id" => "2",
                    "content" => [
                      %{
                        "children" => [
                          %{
                            "text" => "Almost"
                          }
                        ],
                        "id" => "2624267863",
                        "type" => "p"
                      }
                    ]
                  }
                },
                %{
                  "rule" => "input like {1945694348}",
                  "score" => 0,
                  "id" => "r3",
                  "feedback" => %{
                    "id" => "3",
                    "content" => [
                      %{
                        "children" => [
                          %{
                            "text" => "No"
                          }
                        ],
                        "id" => "2624267864",
                        "type" => "p"
                      }
                    ]
                  }
                }
              ]
            }
          ]
        },
        "choices" => [
          %{
            "content" => [
              %{
                "children" => [
                  %{
                    "text" => "Choice A"
                  }
                ],
                "id" => "644441764",
                "type" => "p"
              }
            ],
            "id" => "3222237681"
          },
          %{
            "content" => [
              %{
                "children" => [
                  %{
                    "text" => "Choice B"
                  }
                ],
                "id" => "2252168149",
                "type" => "p"
              }
            ],
            "id" => "1945694347"
          },
          %{
            "content" => [
              %{
                "children" => [
                  %{
                    "text" => "Choice C"
                  }
                ],
                "id" => "2252168150",
                "type" => "p"
              }
            ],
            "id" => "1945694348"
          }
        ]
      }

      datashop_session_id_user1 = UUID.uuid4()
      datashop_session_id_user2 = UUID.uuid4()

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_guest_user(%{}, :user2_guest)
        |> Seeder.add_activity(
          %{title: "activity 1", content: content},
          :publication,
          :project,
          :author,
          :activity_1
        )
        |> Seeder.add_activity(
          %{title: "activity 2", content: content},
          :publication,
          :project,
          :author,
          :activity_2
        )

      map =
        map
        |> Seeder.add_page(
          %{
            graded: false,
            content: %{
              "model" => [
                %{
                  "type" => "activity-reference",
                  "activity_id" => Map.get(map, :activity_1).revision.resource_id
                }
              ]
            }
          },
          :ungraded_page
        )
        |> Seeder.add_page(
          %{
            graded: true,
            content: %{
              "model" => [
                %{
                  "type" => "activity-reference",
                  "activity_id" => Map.get(map, :activity_2).revision.resource_id
                }
              ]
            }
          },
          :graded_page
        )
        |> Seeder.ensure_published()
        |> Seeder.create_section_resources()
        |> Seeder.simulate_student_attempt(%StudentAttemptSeed{
          user: :user1,
          datashop_session_id: datashop_session_id_user1,
          resource: :ungraded_page,
          activity: :activity_1,
          get_part_inputs: &[%{attempt_guid: &1, input: %StudentInput{input: "3222237681"}}],
          transformed_model: content,
          resource_attempt_tag: :user1_ungraded_page_attempt,
          activity_attempt_tag: :user1_ungraded_page_activity_1_attempt,
          part_attempt_tag: :user1_graded_page_activity_1_part_1_attempt
        })
        |> Seeder.simulate_student_attempt(%StudentAttemptSeed{
          user: :user2_guest,
          datashop_session_id: datashop_session_id_user2,
          resource: :ungraded_page,
          activity: :activity_1,
          get_part_inputs: &[%{attempt_guid: &1, input: %StudentInput{input: "3222237681"}}],
          transformed_model: content,
          resource_attempt_tag: :user1_ungraded_page_attempt,
          activity_attempt_tag: :user1_ungraded_page_activity_1_attempt,
          part_attempt_tag: :user1_graded_page_activity_1_part_1_attempt
        })
        |> Seeder.simulate_student_attempt(%StudentAttemptSeed{
          user: :user1,
          datashop_session_id: datashop_session_id_user1,
          resource: :graded_page,
          activity: :activity_2,
          get_part_inputs: &[%{attempt_guid: &1, input: %StudentInput{input: "3222237681"}}],
          transformed_model: content,
          resource_attempt_tag: :user1_graded_page_attempt,
          activity_attempt_tag: :user1_graded_page_activity_2_attempt,
          part_attempt_tag: :user1_graded_page_activity_2_part_1_attempt
        })
        |> Seeder.finalize_graded_attempt(datashop_session_id_user1, nil, %{
          section: :section,
          attempt: :user1_graded_page_attempt
        })

      map =
        map
        |> Map.put(:datashop_session_id_user1, datashop_session_id_user1)
        |> Map.put(:datashop_session_id_user2, datashop_session_id_user2)

      {:ok, map}
    end

    test "generates a valid export", %{
      project: project,
      user1: user1,
      user2_guest: user2_guest
    } do
      xml = Datashop.export(project.id)

      xml =~ ~s|<?xml version="1.0" encoding="UTF-8"?>|

      xml =~
        ~s|<tutor_related_message_sequence version_number="4" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://pslcdatashop.org/dtd/tutor_message_v4.xsd">|

      xml =~ ~s|<context_message|
      xml =~ ~s|<tool_message|
      xml =~ ~s|<tutor_message|
      xml =~ ~s|<user_id>#{user1.email}</user_id>|
      xml =~ ~s|<user_id>#{user2_guest.email}</user_id>|
      xml =~ ~s|<event_descriptor>|
      xml =~ ~s|<selection>Activity activity_1, part 1</selection>|
      xml =~ ~s|<action>Multiple choice submission</action>|
      xml =~ ~s|<input><![CDATA[<p>Correct</p>]]></input>|
      xml =~ ~s|</event_descriptor>|
      xml =~ ~s|<action_evaluation>CORRECT</action_evaluation>|
    end

    test "uses correct datashop session id for user and uses guest user sub for user_id", %{
      project: project,
      user1: user1,
      user2_guest: user2_guest,
      datashop_session_id_user1: datashop_session_id_user1,
      datashop_session_id_user2: datashop_session_id_user2
    } do
      xml = Datashop.export(project.id)

      assert xml
             |> xpath(
               ~x"//context_message/meta[user_id/text() = '#{user1.email}']/session_id/text()"
             )
             |> to_string() == datashop_session_id_user1

      assert xml
             |> xpath(
               ~x"//context_message/meta[user_id/text() = '#{user2_guest.sub}']/session_id/text()"
             )
             |> to_string() == datashop_session_id_user2
    end

    test "uses correct timestamp for context tool and tutor messages", %{
      project: project,
      user1: user1,
      activity_2: graded_page_activity,
      user1_graded_page_attempt: user1_graded_page_attempt
    } do
      xml = Datashop.export(project.id)

      attempts = Hierarchy.get_latest_attempts(user1_graded_page_attempt.id)
      {_, part_map} = Map.get(attempts, graded_page_activity.resource.id)

      date_accessed = user1_graded_page_attempt.inserted_at |> format_date()
      date_submitted = Map.get(part_map, "1").date_submitted |> format_date()

      assert xml
             |> xpath(~x"//context_message/meta[user_id/text() = '#{user1.email}']/time/text()")
             |> to_string() == date_accessed

      assert xml
             |> xpath(~x"//tool_message/meta[user_id/text() = '#{user1.email}']/time/text()")
             |> to_string() == date_submitted

      assert xml
             |> xpath(~x"//tutor_message/meta[user_id/text() = '#{user1.email}']/time/text()")
             |> to_string() == date_submitted
    end
  end

  defp format_date(date) do
    {:ok, time} = Timex.format(date, "{YYYY}-{0M}-{0D} {0h24}:{0m}:{0s}")
    time
  end
end
