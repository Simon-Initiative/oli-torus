defmodule Oli.ActivityEditingTest do
  use Oli.DataCase

  alias Oli.Authoring.Editing.{ResourceContext, PageEditor, ActivityEditor, ObjectiveEditor}
  alias Oli.Resources

  describe "activity editing" do
    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.add_objective("objective 1", :obj1)
      |> Seeder.add_objective("objective 2", :obj2)
    end

    test "create/4 creates an activity revision", %{author: author, project: project} do
      content = %{"stem" => "Hey there"}

      {:ok, {revision, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

      assert revision.content == content
    end

    test "create/4 creates an activity revision with objectives", %{
      author: author,
      project: project,
      obj1: obj1,
      obj2: obj2
    } do
      content = %{
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
                },
                %{
                  "rule" => "input like {b}",
                  "score" => 1,
                  "id" => "r2",
                  "feedback" => %{"id" => "2", "content" => "almost"}
                },
                %{
                  "rule" => "input like {c}",
                  "score" => 0,
                  "id" => "r3",
                  "feedback" => %{"id" => "3", "content" => "no"}
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
                },
                %{
                  "rule" => "input like {b}",
                  "score" => 1,
                  "id" => "r2",
                  "feedback" => %{"id" => "5", "content" => "almost"}
                },
                %{
                  "rule" => "input like {c}",
                  "score" => 0,
                  "id" => "r3",
                  "feedback" => %{"id" => "6", "content" => "no"}
                }
              ],
              "scoringStrategy" => "best"
            }
          ],
          "transformations" => []
        }
      }

      {:ok, {revision, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [
          obj1.resource.id,
          obj2.resource.id
        ])

      assert revision.content == content

      assert Map.get(revision.objectives, "1") == [obj1.resource.id, obj2.resource.id]
      assert Map.get(revision.objectives, "2") == [obj1.resource.id, obj2.resource.id]
    end

    test "create_bulk/3 creates a list of activity revisions", %{author: author, project: project} do

      bulk_content = [%{
        "activityTypeSlug" => "oli_multiple_choice",
        "objectives" => [],
        "content" => %{"stem" => "Hey there"},
        "title" => "title1",
        "tags" => []
      }, %{
        "activityTypeSlug" => "oli_short_answer",
        "objectives" => [],
        "content" => %{"stem" => "Hey there2"},
        "title" => "title2",
        "tags" => []
      }]

      {:ok, [%{activity: activity1, activity_type_slug: activity_type_slug1}, %{activity: activity2, activity_type_slug: activity_type_slug2}]} =
        ActivityEditor.create_bulk(project.slug, author, bulk_content)

      assert activity1.title == "title1"
      assert activity_type_slug1 == "oli_multiple_choice"
      assert activity2.title == "title2"
      assert activity_type_slug2 == "oli_short_answer"
    end

    test "edit/5 does not release the lock when 'releaseLock' is absent", %{
      project: project,
      author: author,
      author2: author2,
      revision1: revision1
    } do
      content = %{"stem" => "Hey there"}

      {:ok, {%{resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

      PageEditor.acquire_lock(project.slug, revision1.slug, author.email)
      update = %{"title" => "edited title"}

      {:ok, _} =
        ActivityEditor.edit(
          project.slug,
          revision1.resource_id,
          resource_id,
          author.email,
          update
        )

      PageEditor.acquire_lock(project.slug, revision1.slug, author2.email)

      result =
        ActivityEditor.edit(
          project.slug,
          revision1.resource_id,
          resource_id,
          author2.email,
          update
        )

      assert {:error, {:lock_not_acquired, _}} = result
    end

    test "edit/5 releases the lock when 'releaseLock' present", %{
      project: project,
      author: author,
      author2: author2,
      revision1: revision1
    } do
      content = %{"stem" => "Hey there"}

      {:ok, {%{resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

      PageEditor.acquire_lock(project.slug, revision1.slug, author.email)
      update = %{"title" => "edited title", "releaseLock" => true}

      {:ok, _} =
        ActivityEditor.edit(
          project.slug,
          revision1.resource_id,
          resource_id,
          author.email,
          update
        )

      PageEditor.acquire_lock(project.slug, revision1.slug, author2.email)

      result =
        ActivityEditor.edit(
          project.slug,
          revision1.resource_id,
          resource_id,
          author2.email,
          update
        )

      assert {:ok, _} = result
    end

    test "edit/5 it updates the activity scoring strategy", %{
      author: author,
      project: project,
      revision1: revision
    } do
      content = %{"stem" => "Hey there"}

      {:ok, {%{slug: slug, resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_multi_input", author, content, [])

      # Verify that we can issue a resource edit that attaches the activity
      update = %{
        "content" => %{
          "customScoring" => true,
          "scoringStrategy" => "best",
          "version" => "0.1.0",
          "model" => [
            %{
              "type" => "activity-reference",
              "id" => "1",
              "activitySlug" => slug
            }
          ]
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)
      assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)

      {:ok, first} =
        ActivityEditor.edit(project.slug, revision.resource_id, resource_id, author.email, update)

      actual = Resources.get_revision!(first.id)
      assert actual.scoring_strategy_id == Oli.Resources.ScoringStrategy.get_id_by_type("best")
    end

    test "edit/5 it sets the default activity scoring strategy when customScoring is false", %{
      author: author,
      project: project,
      revision1: revision
    } do
      content = %{"stem" => "Hey there"}

      {:ok, {%{slug: slug, resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_multi_input", author, content, [])

      # Verify that we can issue a resource edit that attaches the activity
      update = %{
        "content" => %{
          "customScoring" => false,
          "version" => "0.1.0",
          "model" => [
            %{
              "type" => "activity-reference",
              "id" => "1",
              "activitySlug" => slug
            }
          ]
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)
      assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)

      {:ok, first} =
        ActivityEditor.edit(project.slug, revision.resource_id, resource_id, author.email, update)

      actual = Resources.get_revision!(first.id)
      assert actual.scoring_strategy_id == Oli.Resources.ScoringStrategy.get_id_by_type("total")
    end

    test "can create and attach an activity to a resource", %{
      author: author,
      project: project,
      revision1: revision
    } do
      content = %{"stem" => "Hey there"}

      {:ok, {%{slug: slug, resource_id: activity_id}, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

      # Verify that we can issue a resource edit that attaches the activity
      update = %{
        "content" => %{
          "version" => "0.1.0",
          "model" => [
            %{
              "type" => "activity-reference",
              "id" => "1",
              "activitySlug" => slug
            }
          ]
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, updated_revision} =
               PageEditor.edit(project.slug, revision.slug, author.email, update)

      # Verify that the slug was translated to the correct activity id
      activity_ref = hd(Map.get(updated_revision.content, "model"))
      assert activity_id == Map.get(activity_ref, "activity_id")
      refute Map.has_key?(activity_ref, "activitySlug")

      # Now generate the resource editing context with this attached activity in place
      # so that we can verify that the activities, editorMap and content are all wired
      # together correctly
      {:ok, %ResourceContext{activities: activities, content: content, editorMap: editorMap}} =
        PageEditor.create_context(project.slug, updated_revision.slug, author)

      activity_ref = hd(Map.get(content, "model"))

      # verifies that the content entry has an activitySlug that references an activity map entry
      activity_slug = Map.get(activity_ref, "activitySlug")
      assert Map.has_key?(activities, activity_slug)

      # and that activity map entry has a type slug that references an editor map entry
      %{typeSlug: typeSlug} = Map.get(activities, activity_slug)
      assert Map.has_key?(editorMap, typeSlug)
    end

    test "can repeatedly edit an activity", %{
      author: author,
      project: project,
      revision1: revision
    } do
      content = %{"stem" => "Hey there"}

      {:ok, {%{slug: slug, resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

      # Verify that we can issue a resource edit that attaches the activity
      update = %{
        "content" => %{
          "version" => "0.1.0",
          "model" => [
            %{
              "type" => "activity-reference",
              "id" => "1",
              "activitySlug" => slug
            }
          ]
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)
      assert {:ok, _} = PageEditor.edit(project.slug, revision.slug, author.email, update)

      update = %{"title" => "edited title"}

      {:ok, first} =
        ActivityEditor.edit(project.slug, revision.resource_id, resource_id, author.email, update)

      actual = Resources.get_revision!(first.id)
      assert actual.title == "edited title"
      assert actual.slug == "edited_title"

      update = %{"title" => "edited title"}

      {:ok, _} =
        ActivityEditor.edit(project.slug, revision.resource_id, resource_id, author.email, update)

      actual2 = Resources.get_revision!(first.id)

      # ensure that it did not create a new revision
      assert actual2.id == actual.id
    end

    test "activity context creation", %{author: author, project: project, revision1: revision} do
      {:ok, {%{slug: slug_1}, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, %{"stem" => "one"}, [])

      # attach the activity
      update = %{
        "content" => %{
          "version" => "0.1.0",
          "model" => [
            %{
              "type" => "activity-reference",
              "id" => "1",
              "activitySlug" => slug_1
            }
          ]
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, %{slug: revision_slug}} =
               PageEditor.edit(project.slug, revision.slug, author.email, update)

      # create the activity context
      {:ok, context} = ActivityEditor.create_context(project.slug, revision_slug, slug_1, author)

      # verify all attributes of the editing context are what we expect
      assert context.activitySlug == slug_1
      assert context.model == %{"stem" => "one"}
      assert context.friendlyName == "Multiple Choice"
      assert context.authoringElement == "oli-multiple-choice-authoring"
      assert context.authoringScript == "oli_multiple_choice_authoring.js"
      assert context.projectSlug == project.slug
      assert context.resourceSlug == revision_slug
      assert context.authorEmail == author.email
      assert length(context.allObjectives) == 2
    end

    test "attaching an unknown activity to a resource fails", %{
      author: author,
      project: project,
      revision1: revision
    } do
      update = %{
        "content" => %{
          "model" => [
            %{
              "type" => "activity-reference",
              "id" => 1,
              "activitySlug" => "missing",
              "purpose" => "none"
            }
          ]
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:error, :not_found} =
               PageEditor.edit(project.slug, revision.slug, author.email, update)
    end

    test "can sync objectives to parts", %{author: author, project: project} do
      {:ok, %{revision: ob1}} =
        ObjectiveEditor.add_new(%{title: "this is an objective"}, author, project)

      {:ok, %{revision: ob2}} =
        ObjectiveEditor.add_new(%{title: "this is another objective"}, author, project)

      # Create a two part activity where each part is tied to one of the objectives above
      content = %{
        "objectives" => %{"1" => [ob1.slug], "2" => [ob2.slug]},
        "content" => %{"authoring" => %{"parts" => [%{"id" => "1"}, %{"id" => "2"}]}}
      }

      {:ok, {revision, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

      assert revision.content["objectives"] == %{"1" => [ob1.slug], "2" => [ob2.slug]}

      # Delete one of the activity parts
      update = %{
        "objectives" => %{"1" => [ob1.resource_id], "2" => [ob2.resource_id]},
        "content" => %{"authoring" => %{"parts" => [%{"id" => "1"}]}}
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      {:ok, updated} =
        ActivityEditor.edit(
          project.slug,
          revision.resource_id,
          revision.resource_id,
          author.email,
          update
        )

      # Verify that the objective tied to that part has been removed as well
      assert updated.objectives == %{"1" => [ob1.resource_id]}
    end
  end
end
