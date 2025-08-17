defmodule Oli.GenAI.Tools.CreateActivityToolTest do
  use Oli.DataCase

  alias Oli.GenAI.Tools.CreateActivityTool
  alias Oli.Accounts.SystemRole

  import Oli.Factory

  setup do
    # Create a system admin author directly using system_role_id
    admin_author = insert(:author, %{system_role_id: SystemRole.role_id().system_admin})

    # Create a project
    project = insert(:project, %{authors: [admin_author]})

    # Create a working publication for the project
    publication = insert(:publication, %{project: project, root_resource_id: nil, published: nil})

    # Ensure activity registration exists (might already be seeded)
    activity_registration =
      case Oli.Activities.get_registration_by_slug("oli_multiple_choice") do
        nil ->
          insert(:activity_registration, %{
            slug: "oli_multiple_choice",
            title: "Multiple Choice"
          })

        existing ->
          existing
      end

    %{
      admin_author: admin_author,
      project: project,
      publication: publication,
      activity_registration: activity_registration
    }
  end

  describe "create activity tool" do
    test "creates a valid multiple choice activity", %{project: project} do
      valid_activity = %{
        "stem" => %{
          "id" => "stem_1",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "What is 2+2?"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        "choices" => [
          %{
            "id" => "choice_1",
            "content" => [
              %{
                "type" => "p",
                "children" => [%{"text" => "3"}]
              }
            ],
            "editor" => "slate",
            "textDirection" => "ltr"
          },
          %{
            "id" => "choice_2",
            "content" => [
              %{
                "type" => "p",
                "children" => [%{"text" => "4"}]
              }
            ],
            "editor" => "slate",
            "textDirection" => "ltr"
          }
        ],
        "authoring" => %{
          "version" => 2,
          "targeted" => [],
          "parts" => [
            %{
              "id" => "part_1",
              "gradingApproach" => "automatic",
              "scoringStrategy" => "average",
              "hints" => [],
              "responses" => [
                %{
                  "id" => "response_correct",
                  "rule" => "input like {choice_2}",
                  "score" => 1,
                  "correct" => true,
                  "feedback" => %{
                    "id" => "feedback_correct",
                    "content" => [
                      %{
                        "type" => "p",
                        "children" => [%{"text" => "Correct!"}]
                      }
                    ],
                    "editor" => "slate",
                    "textDirection" => "ltr"
                  }
                },
                %{
                  "id" => "response_incorrect",
                  "rule" => "input like {.*}",
                  "score" => 0,
                  "correct" => false,
                  "feedback" => %{
                    "id" => "feedback_incorrect",
                    "content" => [
                      %{
                        "type" => "p",
                        "children" => [%{"text" => "Incorrect"}]
                      }
                    ],
                    "editor" => "slate",
                    "textDirection" => "ltr"
                  }
                }
              ]
            }
          ],
          "transformations" => [],
          "previewText" => "What is 2+2?"
        }
      }

      activity_json = Jason.encode!(valid_activity)

      frame = %{}

      result =
        CreateActivityTool.execute(
          %{
            project_slug: project.slug,
            activity_json: activity_json,
            activity_type_slug: "oli_multiple_choice"
          },
          frame
        )

      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => success_text}] = response.content

      # Parse the JSON response
      {:ok, response_data} = Jason.decode(success_text)
      assert response_data["success"] == true
      assert response_data["message"] == "Activity created successfully"
      assert Map.has_key?(response_data, "activity")

      activity = response_data["activity"]
      assert Map.has_key?(activity, "resource_id")
      assert Map.has_key?(activity, "revision_id")
      assert Map.has_key?(activity, "slug")
      assert Map.has_key?(activity, "title")
    end

    test "returns error for invalid JSON", %{project: project} do
      invalid_json = "{ invalid json"

      frame = %{}

      result =
        CreateActivityTool.execute(
          %{
            project_slug: project.slug,
            activity_json: invalid_json,
            activity_type_slug: "oli_multiple_choice"
          },
          frame
        )

      assert {:reply, response, ^frame} = result
      assert response.isError == true
      assert [%{"type" => "text", "text" => error_text}] = response.content
      assert String.contains?(error_text, "Activity creation failed")
      assert String.contains?(error_text, "Invalid JSON")
    end

    test "returns error for invalid activity structure", %{project: project} do
      # Create an activity with malformed content that should fail content validation
      invalid_activity = %{
        "stem" => %{
          "content" => "this should be a list, not a string"
        }
      }

      activity_json = Jason.encode!(invalid_activity)

      frame = %{}

      result =
        CreateActivityTool.execute(
          %{
            project_slug: project.slug,
            activity_json: activity_json,
            activity_type_slug: "oli_multiple_choice"
          },
          frame
        )

      assert {:reply, response, ^frame} = result
      assert response.isError == true
      assert [%{"type" => "text", "text" => error_text}] = response.content
      assert String.contains?(error_text, "Activity creation failed")
    end

    test "returns error for non-existent project" do
      valid_activity = %{
        "stem" => %{
          "id" => "stem_1",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Test question"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        "authoring" => %{
          "version" => 2,
          "parts" => [],
          "transformations" => [],
          "previewText" => "Test question"
        }
      }

      activity_json = Jason.encode!(valid_activity)

      frame = %{}

      result =
        CreateActivityTool.execute(
          %{
            project_slug: "non-existent-project",
            activity_json: activity_json,
            activity_type_slug: "oli_multiple_choice"
          },
          frame
        )

      assert {:reply, response, ^frame} = result
      assert response.isError == true
      assert [%{"type" => "text", "text" => error_text}] = response.content
      assert String.contains?(error_text, "Activity creation failed")
    end

    test "extracts title from preview text", %{project: project} do
      activity_with_preview = %{
        "stem" => %{
          "id" => "stem_1",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "Some question"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        "authoring" => %{
          "version" => 2,
          "parts" => [],
          "transformations" => [],
          "previewText" => "Custom Preview Title"
        }
      }

      activity_json = Jason.encode!(activity_with_preview)

      frame = %{}

      result =
        CreateActivityTool.execute(
          %{
            project_slug: project.slug,
            activity_json: activity_json,
            activity_type_slug: "oli_multiple_choice"
          },
          frame
        )

      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => success_text}] = response.content

      # Parse the JSON response and check title
      {:ok, response_data} = Jason.decode(success_text)
      assert response_data["activity"]["title"] == "Custom Preview Title"
    end

    test "extracts title from stem content when no preview text", %{project: project} do
      activity_without_preview = %{
        "stem" => %{
          "id" => "stem_1",
          "content" => [
            %{
              "type" => "p",
              "children" => [%{"text" => "What is the meaning of life?"}]
            }
          ],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        "authoring" => %{
          "version" => 2,
          "parts" => [],
          "transformations" => [],
          "previewText" => ""
        }
      }

      activity_json = Jason.encode!(activity_without_preview)

      frame = %{}

      result =
        CreateActivityTool.execute(
          %{
            project_slug: project.slug,
            activity_json: activity_json,
            activity_type_slug: "oli_multiple_choice"
          },
          frame
        )

      assert {:reply, response, ^frame} = result
      assert [%{"type" => "text", "text" => success_text}] = response.content

      # Parse the JSON response and check title
      {:ok, response_data} = Jason.decode(success_text)
      assert response_data["activity"]["title"] == "What is the meaning of life?"
    end
  end

  describe "system admin requirement" do
    test "fails when no system admin exists", %{project: project} do
      # Delete the system admin author we created in setup
      Oli.Repo.delete_all(Oli.Accounts.Author)

      valid_activity = %{
        "stem" => %{
          "id" => "stem_1",
          "content" => [%{"type" => "p", "children" => [%{"text" => "Test"}]}],
          "editor" => "slate",
          "textDirection" => "ltr"
        },
        "authoring" => %{
          "version" => 2,
          "parts" => [],
          "transformations" => [],
          "previewText" => "Test"
        }
      }

      activity_json = Jason.encode!(valid_activity)

      frame = %{}

      result =
        CreateActivityTool.execute(
          %{
            project_slug: project.slug,
            activity_json: activity_json,
            activity_type_slug: "oli_multiple_choice"
          },
          frame
        )

      assert {:reply, response, ^frame} = result
      assert response.isError == true
      assert [%{"type" => "text", "text" => error_text}] = response.content
      assert String.contains?(error_text, "No system admin author found")
    end
  end
end
