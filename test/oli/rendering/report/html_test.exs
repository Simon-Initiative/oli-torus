defmodule Oli.Content.Report.HtmlTest do
  use Oli.DataCase

  alias Oli.Activities.Model.{Part}
  alias Lti_1p3.Roles.ContextRoles

  alias Oli.Delivery.Sections
  alias Oli.Rendering.Context
  alias Oli.Rendering.Report
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Activities

  defp setup_fetching_attempt_records(_) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_activity(
        %{
          activity_type_id: Activities.get_registration_by_slug("oli_likert").id,
          content: %{
            stem: %{
              content: [
                %{
                  type: "p",
                  children: [
                    %{
                      text: "prompt"
                    }
                  ],
                  id: "ae528138370c94fc08c3cde1bf57c388c"
                }
              ]
            },
            choices: [
              %{
                content: [
                  %{
                    type: "p",
                    children: [
                      %{
                        text: "1: Not at all true of me"
                      }
                    ]
                  }
                ],
                id: "1"
              },
              %{
                content: [
                  %{
                    type: "p",
                    children: [
                      %{
                        text: "2"
                      }
                    ]
                  }
                ],
                id: "2"
              },
              %{
                content: [
                  %{
                    type: "p",
                    children: [
                      %{
                        text: "3: Very true of me"
                      }
                    ]
                  }
                ],
                id: "3"
              }
            ],
            items: [
              %{
                content: [
                  %{
                    type: "p",
                    children: [
                      %{
                        text: "I space out my study sessions in the time leading up to the exam."
                      }
                    ]
                  }
                ],
                id: "fecadc471498487094863c340e719f93",
                required: "true",
                group: "Deep"
              }
            ]
          }
        },
        :publication,
        :project,
        :author,
        :activity_a
      )

    attrs = %{
      title: "page1",
      content: %{
        "model" => [
          %{
            "type" => "activity-reference",
            "activity_id" => Map.get(map, :activity_a).resource.id
          }
        ]
      },
      graded: false
    }

    Seeder.add_page(map, attrs, :un_graded_page)
    |> Seeder.create_section_resources()
    |> Seeder.create_resource_attempt(
      %{attempt_number: 1},
      :user1,
      :page1,
      :revision1,
      :attempt1
    )
    |> Seeder.create_activity_attempt(
      %{attempt_number: 1, transformed_model: nil},
      :activity_a,
      :attempt1,
      :activity_attempt1
    )
    |> Seeder.create_part_attempt(
      %{attempt_number: 1},
      %Part{
        id: "fecadc471498487094863c340e719f93",
        responses: [%{files: [], input: "2"}],
        hints: []
      },
      :activity_attempt1,
      :part1_attempt1
    )
  end

  describe "html activity renderer" do
    setup [:setup_tags, :setup_fetching_attempt_records]

    test "renders well-formed report properly", %{
      section: section,
      activity_a: activity_a,
      user1: user1
    } do
      {:ok, %Enrollment{} = enrollment} =
        Sections.enroll(user1.id, section.id, [ContextRoles.get_role(:context_learner)])

      element = %{
        "id" => "1855946510",
        "type" => "report",
        "activityId" => activity_a.resource.id
      }

      rendered_html =
        Report.render(
          %Context{enrollment: enrollment, user: user1, section_slug: section.slug},
          element,
          Report.Html
        )

      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~
               ~s|<div id="1855946510" class="activity-report"><div class="activity-report-label">Report</div><div class="content-purpose-content content">|

      assert rendered_html_string =~
               ~s|<div data-react-class="Components.LikertReportRenderer" data-react-props="|
    end
  end
end
