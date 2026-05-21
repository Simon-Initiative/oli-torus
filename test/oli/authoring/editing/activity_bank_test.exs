defmodule Oli.Authoring.Editing.ActivityBankTest do
  use Oli.DataCase

  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Authoring.Editing.ActivityBank
  alias Oli.Resources.ResourceType
  alias Oli.Seeder

  describe "create/3" do
    setup [:project_with_metadata]

    test "creates a banked activity and resolves objective and tag titles", %{
      author: author,
      objective: objective,
      project: project,
      tag: tag
    } do
      assert {:ok, {revision, _content}} =
               ActivityBank.create(project.slug, author, %{
                 type: "oli_multiple_choice",
                 title: "Created from titles",
                 objectives: [objective.title],
                 tags: [tag.title],
                 content: activity_content()
               })

      assert revision.scope == :banked
      assert revision.tags == [tag.resource_id]
      assert Map.get(revision.objectives, "1") == [objective.resource_id]
      assert Map.get(revision.objectives, "2") == [objective.resource_id]
    end

    test "rejects unauthorized authors before creating activity", %{
      project: project
    } do
      unauthorized_author =
        author_fixture(%{
          email: "unauthorized#{System.unique_integer([:positive])}@test.com",
          system_role_id: Oli.Accounts.SystemRole.role_id().author
        })

      assert {:error, {:not_authorized}} =
               ActivityBank.create(project.slug, unauthorized_author, %{
                 type: "oli_multiple_choice",
                 title: "Unauthorized activity",
                 content: activity_content()
               })
    end

    test "accepts numeric objective and tag ids scoped to the project", %{
      author: author,
      objective: objective,
      project: project,
      tag: tag
    } do
      assert {:ok, {revision, _content}} =
               ActivityBank.create(project.slug, author, %{
                 type: "oli_multiple_choice",
                 title: "Created from ids",
                 objectives: [objective.resource_id],
                 tags: [tag.resource_id],
                 content: activity_content()
               })

      assert revision.tags == [tag.resource_id]
      assert Map.get(revision.objectives, "1") == [objective.resource_id]
      assert Map.get(revision.objectives, "2") == [objective.resource_id]
    end

    test "rejects numeric objective and tag ids outside the project", %{
      author: author,
      project: project
    } do
      {:ok, other} = project_with_metadata(%{})
      objective_error = "Objective resource '#{other.objective.resource_id}' not found in project"
      tag_error = "Tag resource '#{other.tag.resource_id}' not found in project"

      assert {:error, ^objective_error} =
               ActivityBank.create(project.slug, author, %{
                 type: "oli_multiple_choice",
                 title: "Cross-project objective",
                 objectives: [other.objective.resource_id],
                 content: activity_content()
               })

      assert {:error, ^tag_error} =
               ActivityBank.create(project.slug, author, %{
                 type: "oli_multiple_choice",
                 title: "Cross-project tag",
                 tags: [other.tag.resource_id],
                 content: activity_content()
               })
    end

    test "rejects numeric ids with the wrong resource type", %{
      author: author,
      project: project,
      tag: tag
    } do
      expected_error =
        "Objective resource '#{tag.resource_id}' does not have the expected resource type"

      assert {:error, ^expected_error} =
               ActivityBank.create(project.slug, author, %{
                 type: "oli_multiple_choice",
                 title: "Wrong type objective",
                 objectives: [tag.resource_id],
                 content: activity_content()
               })
    end
  end

  describe "create_bulk/3" do
    setup [:project_with_metadata]

    test "creates banked activities and resolves metadata titles for each item", %{
      author: author,
      objective: objective,
      project: project,
      tag: tag
    } do
      assert {:ok, [%{activity: revision}]} =
               ActivityBank.create_bulk(project.slug, author, [
                 %{
                   activityTypeSlug: "oli_multiple_choice",
                   title: "Bulk created from titles",
                   objectives: [objective.title],
                   tags: [tag.title],
                   content: activity_content()
                 }
               ])

      assert revision.scope == :banked
      assert revision.tags == [tag.resource_id]
      assert Map.get(revision.objectives, "1") == [objective.resource_id]
      assert Map.get(revision.objectives, "2") == [objective.resource_id]
    end

    test "preserves explicit objective maps for each item", %{
      author: author,
      objective: objective,
      project: project
    } do
      assert {:ok, [%{activity: revision}]} =
               ActivityBank.create_bulk(project.slug, author, [
                 %{
                   activityTypeSlug: "oli_multiple_choice",
                   title: "Bulk created with objective map",
                   objective_map: %{"1" => [objective.resource_id]},
                   content: activity_content()
                 }
               ])

      assert revision.scope == :banked
      assert revision.objectives == %{"1" => [objective.resource_id]}
    end

    test "rejects unauthorized authors before bulk creation", %{
      project: project
    } do
      unauthorized_author =
        author_fixture(%{
          email: "unauthorized#{System.unique_integer([:positive])}@test.com",
          system_role_id: Oli.Accounts.SystemRole.role_id().author
        })

      assert {:error, {:not_authorized}} =
               ActivityBank.create_bulk(project.slug, unauthorized_author, [
                 %{
                   activityTypeSlug: "oli_multiple_choice",
                   title: "Unauthorized bulk activity",
                   content: activity_content()
                 }
               ])
    end
  end

  describe "mutations" do
    setup [:project_with_metadata]

    test "rejects unauthorized authors before update and delete", %{
      author: author,
      project: project
    } do
      unauthorized_author =
        author_fixture(%{
          email: "unauthorized#{System.unique_integer([:positive])}@test.com",
          system_role_id: Oli.Accounts.SystemRole.role_id().author
        })

      assert {:ok, {revision, _content}} =
               ActivityBank.create(project.slug, author, %{
                 type: "oli_multiple_choice",
                 title: "Authorized activity",
                 content: activity_content()
               })

      assert {:error, {:not_authorized}} =
               ActivityBank.update(project.slug, unauthorized_author, revision.resource_id, %{
                 "title" => "Unauthorized update"
               })

      assert {:error, {:not_authorized}} =
               ActivityBank.delete(project.slug, unauthorized_author, revision.resource_id)

      assert {:error, {:not_authorized}} =
               ActivityBank.delete_bulk(project.slug, unauthorized_author, [revision.resource_id])
    end

    test "rejects non-banked resources before update and delete", %{
      author: author,
      project: project,
      publication: publication,
      tag: tag
    } do
      %{revision: embedded_revision} =
        Seeder.create_activity(
          %{
            scope: :embedded,
            title: "Embedded activity",
            content: %{model: activity_content()}
          },
          publication,
          project,
          author
        )

      expected_scope_error =
        "Activity resource '#{embedded_revision.resource_id}' is not banked"

      assert {:error, ^expected_scope_error} =
               ActivityBank.update(project.slug, author, embedded_revision.resource_id, %{
                 "title" => "Updated embedded"
               })

      assert {:error, ^expected_scope_error} =
               ActivityBank.delete(project.slug, author, embedded_revision.resource_id)

      assert {:error, ^expected_scope_error} =
               ActivityBank.delete_bulk(project.slug, author, [embedded_revision.resource_id])

      expected_type_error =
        "Activity resource '#{tag.resource_id}' does not have the expected resource type"

      assert {:error, ^expected_type_error} =
               ActivityBank.update(project.slug, author, tag.resource_id, %{
                 "title" => "Updated tag"
               })
    end
  end

  describe "query/4" do
    setup [:project_with_activity_bank]

    test "queries banked activities from JSON-like logic and paging maps", %{
      author: author,
      project: project
    } do
      assert {:ok, result} =
               ActivityBank.query(
                 project.slug,
                 author,
                 %{
                   "conditions" => %{
                     "fact" => "objectives",
                     "operator" => "contains",
                     "value" => [2]
                   }
                 },
                 %{"limit" => 5, "offset" => 0}
               )

      assert result.totalCount == 1
      assert result.rowCount == 1
      assert [%{title: "Banked objective 2"}] = result.rows
    end

    test "does not return embedded or deleted activities", %{author: author, project: project} do
      assert {:ok, result} =
               ActivityBank.query(
                 project.slug,
                 author,
                 %{"conditions" => nil},
                 %{"limit" => 10, "offset" => 0}
               )

      assert Enum.map(result.rows, & &1.title) == ["Banked objective 1", "Banked objective 2"]
      assert result.totalCount == 2
    end
  end

  describe "context/2" do
    setup [:project_with_activity_bank]

    test "builds the Activity Bank editor context", %{author: author, project: project} do
      assert {:ok, context} = ActivityBank.context(project.slug, author)

      assert context.authorEmail == author.email
      assert context.projectSlug == project.slug
      assert context.totalCount == 2
      assert is_map(context.editorMap)
      assert is_list(context.allObjectives)
      assert is_list(context.allTags)
    end
  end

  defp project_with_activity_bank(_context) do
    map = Seeder.base_project_with_resource2()

    Seeder.create_activity(
      %{
        scope: :banked,
        objectives: %{"1" => [1]},
        title: "Banked objective 1",
        content: %{model: %{stem: "this is the first question"}}
      },
      map.publication,
      map.project,
      map.author
    )

    Seeder.create_activity(
      %{
        scope: :banked,
        objectives: %{"1" => [2]},
        title: "Banked objective 2",
        content: %{model: %{stem: "this is the second question"}}
      },
      map.publication,
      map.project,
      map.author
    )

    Seeder.create_activity(
      %{
        scope: :banked,
        deleted: true,
        objectives: %{"1" => [2]},
        title: "Deleted banked",
        content: %{model: %{stem: "this is deleted"}}
      },
      map.publication,
      map.project,
      map.author
    )

    Seeder.create_activity(
      %{
        scope: :embedded,
        objectives: %{"1" => [2]},
        title: "Embedded",
        content: %{model: %{stem: "this is embedded"}}
      },
      map.publication,
      map.project,
      map.author
    )

    {:ok, map}
  end

  defp project_with_metadata(_context) do
    map =
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("Objective A", :objective)

    {:ok, tag} =
      ResourceEditor.create(map.project.slug, map.author, ResourceType.id_for_tag(), %{
        "title" => "Easy"
      })

    {:ok, Map.merge(map, %{objective: map.objective.revision, tag: tag})}
  end

  defp activity_content do
    %{
      "stem" => "1",
      "authoring" => %{
        "parts" => [
          %{
            "id" => "1",
            "responses" => [
              %{
                "rule" => "input like {a}",
                "score" => 10,
                "id" => "r1",
                "feedback" => %{"id" => "1", "content" => "yes"}
              }
            ],
            "scoringStrategy" => "best"
          },
          %{
            "id" => "2",
            "responses" => [
              %{
                "rule" => "input like {a}",
                "score" => 2,
                "id" => "r1",
                "feedback" => %{"id" => "4", "content" => "yes"}
              }
            ],
            "scoringStrategy" => "best"
          }
        ],
        "transformations" => []
      }
    }
  end
end
