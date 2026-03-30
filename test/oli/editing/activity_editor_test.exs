defmodule Oli.ActivityEditingTest do
  use Oli.DataCase

  import Mox

  alias Oli.Authoring.Editing.{ResourceContext, PageEditor, ActivityEditor, ObjectiveEditor}
  alias Oli.Resources

  describe "activity editing" do
    setup :verify_on_exit!

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

    test "create/4 clones the starter bundle for new oli_embedded activities", %{
      author: author,
      project: project
    } do
      content = %{
        "base" => "embedded",
        "src" => "index.html",
        "title" => "Embedded activity",
        "stem" => %{"content" => []},
        "modelXml" => """
        <embed_activity id="custom_side" width="670" height="300">
          <title>Custom Activity</title>
          <source>webcontent/custom_activity/customactivity.js</source>
          <assets>
            <asset name="layout">webcontent/custom_activity/layout.html</asset>
            <asset name="controls">webcontent/custom_activity/controls.html</asset>
          </assets>
        </embed_activity>
        """,
        "resourceBase" => "1234",
        "resourceURLs" => [],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [],
              "hints" => [],
              "scoringStrategy" => "average"
            }
          ],
          "previewText" => ""
        }
      }

      expect(Oli.Test.MockAws, :request, 3, fn %ExAws.Operation.S3{} = op ->
        send(self(), {:aws_request, op})

        case op.http_method do
          :get ->
            assert op.params["prefix"] == "media/webcontent/custom_activity/"

            {:ok,
             %{
               status_code: 200,
               body: %{
                 contents: [
                   %{key: "media/webcontent/custom_activity/customactivity.js"},
                   %{key: "media/webcontent/custom_activity/layout.html"}
                 ]
               }
             }}

          :put ->
            assert op.headers["x-amz-acl"] == "public-read"
            assert String.starts_with?(op.headers["x-amz-copy-source"], "/torus-media-test/")
            assert String.contains?(op.path, "/webcontent/custom_activity/")
            assert String.starts_with?(op.path, "media/bundles/")

            {:ok, %{status_code: 200}}
        end
      end)

      {:ok, {revision, _}} =
        ActivityEditor.create(project.slug, "oli_embedded", author, content, [])

      assert revision.content["resourceBase"] =~ ~r/^bundles\//
      assert revision.content["resourceBase"] != "1234"

      assert_received {:aws_request, %ExAws.Operation.S3{http_method: :get}}
      assert_received {:aws_request, %ExAws.Operation.S3{http_method: :put}}
      assert_received {:aws_request, %ExAws.Operation.S3{http_method: :put}}
    end

    test "create/4 falls back to the original embedded model when bundle cloning fails", %{
      author: author,
      project: project
    } do
      content = %{
        "base" => "embedded",
        "src" => "index.html",
        "title" => "Embedded activity",
        "stem" => %{"content" => []},
        "modelXml" => """
        <embed_activity id="custom_side" width="670" height="300">
          <title>Custom Activity</title>
          <source>webcontent/custom_activity/customactivity.js</source>
        </embed_activity>
        """,
        "resourceBase" => "1234",
        "resourceURLs" => [],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [],
              "hints" => [],
              "scoringStrategy" => "average"
            }
          ],
          "previewText" => ""
        }
      }

      expect(Oli.Test.MockAws, :request, 2, fn %ExAws.Operation.S3{} = op ->
        assert op.http_method == :get
        {:error, :timeout}
      end)

      {:ok, {revision, _}} =
        ActivityEditor.create(project.slug, "oli_embedded", author, content, [])

      assert revision.content["resourceBase"] == "1234"
      assert revision.content["modelXml"] == content["modelXml"]

      assert revision.content["bundleStatus"] == %{
               "code" => "missing_starter_bundle_source",
               "message" =>
                 "Starter bundle files were not found in the media bucket. Ensure the default embedded bundle exists under media/webcontent/custom_activity/."
             }
    end

    test "create/4 preserves an existing oli_embedded bundle resourceBase", %{
      author: author,
      project: project
    } do
      content = %{
        "base" => "embedded",
        "src" => "index.html",
        "title" => "Embedded activity",
        "stem" => %{"content" => []},
        "modelXml" => """
        <embed_activity id="custom_side" width="670" height="300">
          <title>Custom Activity</title>
          <source>webcontent/custom_activity/customactivity.js</source>
        </embed_activity>
        """,
        "resourceBase" => "bundles/existing-bundle",
        "resourceURLs" => [],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [],
              "hints" => [],
              "scoringStrategy" => "average"
            }
          ],
          "previewText" => ""
        }
      }

      {:ok, {revision, _}} =
        ActivityEditor.create(project.slug, "oli_embedded", author, content, [])

      assert revision.content["resourceBase"] == "bundles/existing-bundle"
    end

    test "repair_embedded_bundle/4 clones a starter bundle for an existing embedded activity", %{
      author: author,
      project: project
    } do
      media_url = Application.fetch_env!(:oli, :media_url)

      content = %{
        "base" => "embedded",
        "src" => "index.html",
        "title" => "Embedded activity",
        "stem" => %{"content" => []},
        "modelXml" => """
        <embed_activity id="custom_side" width="670" height="300">
          <title>Custom Activity</title>
          <source>webcontent/custom_activity/customactivity.js</source>
          <assets>
            <asset name="layout">webcontent/custom_activity/layout.html</asset>
            <asset name="uploaded">bundles/1234/webcontent/uploads/existing.css</asset>
          </assets>
        </embed_activity>
        """,
        "resourceBase" => "1234",
        "resourceURLs" => [
          "#{media_url}/media/bundles/1234/webcontent/uploads/existing.css"
        ],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [],
              "hints" => [],
              "scoringStrategy" => "average"
            }
          ],
          "previewText" => ""
        }
      }

      expect(Oli.Test.MockAws, :request, 2, fn %ExAws.Operation.S3{} = op ->
        assert op.http_method == :get
        {:error, :timeout}
      end)

      {:ok, {revision, _}} =
        ActivityEditor.create(project.slug, "oli_embedded", author, content, [])

      assert revision.content["bundleStatus"] == %{
               "code" => "missing_starter_bundle_source",
               "message" =>
                 "Starter bundle files were not found in the media bucket. Ensure the default embedded bundle exists under media/webcontent/custom_activity/."
             }

      repair_model =
        revision.content
        |> Map.put("title", "Unsaved title change")
        |> Map.put("resourceBase", "bundles/foreign-bundle")
        |> Map.put("resourceURLs", [
          "#{media_url}/media/bundles/foreign-bundle/webcontent/uploads/existing.css"
        ])
        |> Map.put(
          "modelXml",
          """
          <embed_activity id="custom_side" width="670" height="300">
            <title>Forged Activity</title>
            <source>webcontent/custom_activity/customactivity.js</source>
            <assets>
              <asset name="layout">webcontent/custom_activity/layout.html</asset>
              <asset name="uploaded">bundles/foreign-bundle/webcontent/uploads/existing.css</asset>
            </assets>
          </embed_activity>
          """
        )

      expect(Oli.Test.MockAws, :request, 4, fn %ExAws.Operation.S3{} = op ->
        case op.http_method do
          :get ->
            assert op.params["prefix"] == "media/webcontent/custom_activity/"

            {:ok,
             %{
               status_code: 200,
               body: %{
                 contents: [
                   %{key: "media/webcontent/custom_activity/customactivity.js"},
                   %{key: "media/webcontent/custom_activity/layout.html"}
                 ]
               }
             }}

          :put ->
            assert String.starts_with?(op.path, "media/bundles/")

            if String.contains?(op.path, "/webcontent/uploads/existing.css") do
              assert op.headers["x-amz-copy-source"] ==
                       "/torus-media-test/media/bundles/1234/webcontent/uploads/existing.css"
            end

            {:ok, %{status_code: 200}}
        end
      end)

      assert {:ok, repaired_model} =
               ActivityEditor.repair_embedded_bundle(
                 project.slug,
                 revision.resource_id,
                 author,
                 repair_model
               )

      assert repaired_model["title"] == "Unsaved title change"
      assert repaired_model["resourceBase"] =~ ~r/^bundles\//
      assert repaired_model["resourceBase"] != "1234"
      assert repaired_model["resourceBase"] != "bundles/foreign-bundle"

      assert repaired_model["resourceURLs"] == [
               "#{media_url}/media/#{repaired_model["resourceBase"]}/webcontent/uploads/existing.css"
             ]

      assert repaired_model["modelXml"] =~ "webcontent/uploads/existing.css"
      refute repaired_model["modelXml"] =~ "bundles/1234/webcontent/uploads/existing.css"

      refute repaired_model["modelXml"] =~
               "bundles/foreign-bundle/webcontent/uploads/existing.css"
    end

    test "repair_embedded_bundle/4 rejects legacy embedded models without bundle fallback status",
         %{
           author: author,
           project: project
         } do
      stored_model = %{
        "base" => "embedded",
        "src" => "index.html",
        "title" => "Embedded activity",
        "stem" => %{"content" => []},
        "modelXml" => """
        <embed_activity id="custom_side" width="670" height="300">
          <title>Custom Activity</title>
          <source>webcontent/custom_activity/customactivity.js</source>
        </embed_activity>
        """,
        "resourceBase" => "bundles/existing-bundle",
        "resourceURLs" => [],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [],
              "hints" => [],
              "scoringStrategy" => "average"
            }
          ],
          "previewText" => ""
        }
      }

      legacy_model = %{
        "base" => "embedded",
        "src" => "index.html",
        "title" => "Embedded activity",
        "stem" => %{"content" => []},
        "modelXml" => """
        <embed_activity id="custom_side" width="670" height="300">
          <title>Custom Activity</title>
          <source>webcontent/custom_activity/customactivity.js</source>
        </embed_activity>
        """,
        "resourceBase" => "1234",
        "resourceURLs" => [],
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [],
              "hints" => [],
              "scoringStrategy" => "average"
            }
          ],
          "previewText" => ""
        }
      }

      {:ok, {revision, _}} =
        ActivityEditor.create(project.slug, "oli_embedded", author, stored_model, [])

      assert {:error, {:invalid_request, "Bundle repair is not available for this activity."}} =
               ActivityEditor.repair_embedded_bundle(
                 project.slug,
                 revision.resource_id,
                 author,
                 legacy_model
               )
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
      bulk_content = [
        %{
          "activityTypeSlug" => "oli_multiple_choice",
          "objectives" => [],
          "content" => %{"stem" => "Hey there"},
          "title" => "title1",
          "tags" => []
        },
        %{
          "activityTypeSlug" => "oli_short_answer",
          "objectives" => [],
          "content" => %{"stem" => "Hey there2"},
          "title" => "title2",
          "tags" => []
        }
      ]

      {:ok,
       [
         %{activity: activity1, activity_type_slug: activity_type_slug1},
         %{activity: activity2, activity_type_slug: activity_type_slug2}
       ]} =
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

    test "can sync objectives when authoring parts are legacy part id strings", %{
      author: author,
      project: project,
      revision1: revision1
    } do
      {:ok, %{revision: ob1}} =
        ObjectiveEditor.add_new(%{title: "this is an objective"}, author, project)

      {:ok, %{revision: ob2}} =
        ObjectiveEditor.add_new(%{title: "this is another objective"}, author, project)

      content = %{
        "content" => %{"authoring" => %{"parts" => ["1", "2"]}}
      }

      {:ok, {revision, _}} =
        ActivityEditor.create(project.slug, "oli_multiple_choice", author, content, [])

      update = %{
        "objectives" => %{"1" => [ob1.resource_id], "2" => [ob2.resource_id]},
        "content" => %{"authoring" => %{"parts" => ["1", "2"]}}
      }

      PageEditor.acquire_lock(project.slug, revision1.slug, author.email)

      {:ok, updated} =
        ActivityEditor.edit(
          project.slug,
          revision1.resource_id,
          revision.resource_id,
          author.email,
          update
        )

      assert updated.objectives == %{
               "1" => [ob1.resource_id],
               "2" => [ob2.resource_id]
             }
    end

    test "edit/5 allows adaptive internal links when idref references a project resource", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, {%{resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-1",
                "type" => "janus-text-flow",
                "custom" => %{
                  "nodes" => [
                    %{
                      "tag" => "p",
                      "children" => [
                        %{
                          "tag" => "a",
                          "idref" => revision.resource_id,
                          "children" => [
                            %{"tag" => "text", "text" => "next", "children" => []}
                          ]
                        }
                      ]
                    }
                  ]
                }
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, _} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 resource_id,
                 author.email,
                 update
               )
    end

    test "edit/5 rejects adaptive AI trigger parts when project triggers are disabled", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, {%{resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "partsLayout" => [
            %{
              "id" => "trigger-1",
              "type" => "janus-ai-trigger",
              "custom" => %{
                "launchMode" => "click",
                "prompt" => "Ask DOT for help"
              }
            }
          ],
          "authoring" => %{
            "parts" => [
              %{
                "id" => "trigger-1",
                "type" => "janus-ai-trigger"
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:error, {:invalid_update_field}} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 resource_id,
                 author.email,
                 update
               )
    end

    test "edit/5 rejects adaptive image AI trigger configuration when project triggers are disabled",
         %{
           author: author,
           project: project,
           revision1: revision
         } do
      {:ok, {%{resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "partsLayout" => [
            %{
              "id" => "image-1",
              "type" => "janus-image",
              "custom" => %{
                "src" => "/images/placeholder-image.svg",
                "enableAiTrigger" => true,
                "aiTriggerPrompt" => "Use this image as context"
              }
            }
          ]
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:error, {:invalid_update_field}} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 resource_id,
                 author.email,
                 update
               )
    end

    test "edit/5 handles malformed adaptive authoring containers without crashing", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, {%{resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "partsLayout" => [
            %{
              "id" => "image-1",
              "type" => "janus-image",
              "custom" => %{
                "src" => "/images/placeholder-image.svg",
                "enableAiTrigger" => true,
                "aiTriggerPrompt" => "Use this image as context"
              }
            }
          ],
          "authoring" => []
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:error, {:invalid_update_field}} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 resource_id,
                 author.email,
                 update
               )
    end

    test "edit/5 allows adaptive AI trigger parts when project triggers are enabled", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, _project} = Oli.Authoring.Course.update_project(project, %{allow_triggers: true})

      {:ok, {%{resource_id: resource_id, content: content}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" =>
          Map.merge(content, %{
            "partsLayout" => [
              %{
                "id" => "trigger-1",
                "type" => "janus-ai-trigger",
                "custom" => %{
                  "launchMode" => "click",
                  "prompt" => "Ask DOT for help"
                }
              }
            ],
            "authoring" => %{
              "parts" => [
                %{
                  "id" => "trigger-1",
                  "type" => "janus-ai-trigger"
                }
              ]
            }
          })
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, _updated_revision} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 resource_id,
                 author.email,
                 update
               )
    end

    test "edit/5 rejects adaptive internal links with href slugs outside the project", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, {%{resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-1",
                "type" => "janus-text-flow",
                "custom" => %{
                  "nodes" => [
                    %{
                      "tag" => "p",
                      "children" => [
                        %{
                          "tag" => "a",
                          "href" => "/course/link/page_not_in_project",
                          "children" => [
                            %{"tag" => "text", "text" => "next", "children" => []}
                          ]
                        }
                      ]
                    }
                  ]
                }
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:error, {:invalid_update_field}} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 resource_id,
                 author.email,
                 update
               )
    end

    test "edit/5 normalizes adaptive internal links to persist idref and resource_id", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, {%{resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-1",
                "type" => "janus-text-flow",
                "custom" => %{
                  "nodes" => [
                    %{
                      "tag" => "p",
                      "children" => [
                        %{
                          "tag" => "a",
                          "resource_id" => "#{revision.resource_id}",
                          "children" => [
                            %{"tag" => "text", "text" => "next", "children" => []}
                          ]
                        }
                      ]
                    }
                  ]
                }
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, updated_revision} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 resource_id,
                 author.email,
                 update
               )

      [part] = get_in(updated_revision.content, ["authoring", "parts"])
      [paragraph] = get_in(part, ["custom", "nodes"])
      [link] = paragraph["children"]

      assert link["idref"] == revision.resource_id
      assert link["resource_id"] == revision.resource_id
      assert link["linkType"] == "page"
    end

    test "edit/5 normalizes adaptive internal href links to persist idref, resource_id, and linkType",
         %{
           author: author,
           project: project,
           revision1: revision
         } do
      {:ok, {%{resource_id: activity_resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-1",
                "type" => "janus-text-flow",
                "custom" => %{
                  "nodes" => [
                    %{
                      "tag" => "p",
                      "children" => [
                        %{
                          "tag" => "a",
                          "href" => "/course/link/#{revision.slug}",
                          "children" => [
                            %{"tag" => "text", "text" => "next", "children" => []}
                          ]
                        }
                      ]
                    }
                  ]
                }
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, updated_revision} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 activity_resource_id,
                 author.email,
                 update
               )

      [part] = get_in(updated_revision.content, ["authoring", "parts"])
      [paragraph] = get_in(part, ["custom", "nodes"])
      [link] = paragraph["children"]

      assert link["idref"] == revision.resource_id
      assert link["resource_id"] == revision.resource_id
      assert link["linkType"] == "page"
    end

    test "edit/5 normalizes adaptive internal href links with query/fragment", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, {%{resource_id: activity_resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-1",
                "type" => "janus-text-flow",
                "custom" => %{
                  "nodes" => [
                    %{
                      "tag" => "p",
                      "children" => [
                        %{
                          "tag" => "a",
                          "href" => "/course/link/#{revision.slug}?x=1#y",
                          "children" => [
                            %{"tag" => "text", "text" => "next", "children" => []}
                          ]
                        }
                      ]
                    }
                  ]
                }
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, updated_revision} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 activity_resource_id,
                 author.email,
                 update
               )

      [part] = get_in(updated_revision.content, ["authoring", "parts"])
      [paragraph] = get_in(part, ["custom", "nodes"])
      [link] = paragraph["children"]

      assert link["idref"] == revision.resource_id
      assert link["resource_id"] == revision.resource_id
      assert link["linkType"] == "page"
    end

    test "edit/5 tolerates janus-text-flow parts without custom nodes during adaptive normalization",
         %{
           author: author,
           project: project,
           revision1: revision
         } do
      {:ok, {%{resource_id: activity_resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-1",
                "type" => "janus-text-flow"
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, updated_revision} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 activity_resource_id,
                 author.email,
                 update
               )

      [part] = get_in(updated_revision.content, ["authoring", "parts"])
      assert part["id"] == "part-1"
      assert part["type"] == "janus-text-flow"
      refute Map.has_key?(part, "custom")
    end

    test "edit/5 emits adaptive dynamic-link authoring telemetry for creation",
         %{
           author: author,
           project: project,
           revision1: revision
         } do
      handler = attach_telemetry([:created])

      {:ok, {%{resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      initial_update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-1",
                "type" => "janus-text-flow",
                "custom" => %{
                  "nodes" => [
                    %{
                      "tag" => "p",
                      "children" => [
                        %{
                          "tag" => "a",
                          "idref" => revision.resource_id,
                          "children" => [%{"tag" => "text", "text" => "next", "children" => []}]
                        }
                      ]
                    }
                  ]
                }
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, _} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 resource_id,
                 author.email,
                 initial_update
               )

      assert_receive {:telemetry_event, [:oli, :adaptive, :dynamic_link, :created], %{count: 1},
                      created_metadata}

      assert created_metadata.project_id == project.id
      assert created_metadata.activity_resource_id == resource_id
      assert created_metadata.source == "activity_editor"

      :telemetry.detach(handler)
    end

    test "edit/5 emits adaptive iframe authoring telemetry for creation",
         %{
           author: author,
           project: project,
           revision1: revision
         } do
      handler = attach_telemetry([:created])

      {:ok, {%{resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      iframe_update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-iframe-1",
                "type" => "janus-capi-iframe",
                "src" => "/course/link/#{revision.slug}",
                "sourceType" => "page",
                "linkType" => "page",
                "idref" => revision.resource_id
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, _} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 resource_id,
                 author.email,
                 iframe_update
               )

      assert_receive {:telemetry_event, [:oli, :adaptive, :dynamic_link, :created], %{count: 1},
                      created_metadata}

      assert created_metadata.project_id == project.id
      assert created_metadata.activity_resource_id == resource_id
      assert created_metadata.source == "iframe_authoring"

      :telemetry.detach(handler)
    end

    test "edit/5 rejects adaptive internal links with out-of-project idref", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, {%{resource_id: resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      {:ok, other_resource} = Resources.create_new_resource()

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-1",
                "type" => "janus-text-flow",
                "custom" => %{
                  "nodes" => [
                    %{
                      "tag" => "p",
                      "children" => [
                        %{
                          "tag" => "a",
                          "idref" => other_resource.id,
                          "children" => [
                            %{"tag" => "text", "text" => "next", "children" => []}
                          ]
                        }
                      ]
                    }
                  ]
                }
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:error, {:invalid_update_field}} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 resource_id,
                 author.email,
                 update
               )
    end

    test "edit/5 allows adaptive iframe internal links when idref references a project resource",
         %{
           author: author,
           project: project,
           revision1: revision
         } do
      {:ok, {%{resource_id: activity_resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-iframe-1",
                "type" => "janus-capi-iframe",
                "src" => "/course/link/#{revision.slug}",
                "sourceType" => "page",
                "idref" => revision.resource_id
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, _updated_revision} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 activity_resource_id,
                 author.email,
                 update
               )
    end

    # @ac "AC-002"
    test "edit/5 normalizes adaptive iframe internal src links to persist idref and resource_id",
         %{
           author: author,
           project: project,
           revision1: revision
         } do
      {:ok, {%{resource_id: activity_resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-iframe-1",
                "type" => "janus-capi-iframe",
                "src" => "/course/link/#{revision.slug}",
                "sourceType" => "page"
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, updated_revision} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 activity_resource_id,
                 author.email,
                 update
               )

      [part] = get_in(updated_revision.content, ["authoring", "parts"])

      assert part["idref"] == revision.resource_id
      assert part["resource_id"] == revision.resource_id
      assert part["linkType"] == "page"
      assert part["sourceType"] == "page"
    end

    # @ac "AC-003"
    test "edit/5 rejects adaptive iframe links with src slugs outside the project", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, {%{resource_id: activity_resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-iframe-1",
                "type" => "janus-capi-iframe",
                "src" => "/course/link/page_not_in_project",
                "sourceType" => "page"
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:error, {:invalid_update_field}} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 activity_resource_id,
                 author.email,
                 update
               )
    end

    # @ac "AC-008"
    test "edit/5 rejects adaptive iframe links with out-of-project idref", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, {%{resource_id: activity_resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      %{revision1: other_project_revision} = Seeder.base_project_with_resource2()

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-iframe-1",
                "type" => "janus-capi-iframe",
                "src" => "/course/link/#{other_project_revision.slug}",
                "sourceType" => "page",
                "idref" => other_project_revision.resource_id
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:error, {:invalid_update_field}} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 activity_resource_id,
                 author.email,
                 update
               )
    end

    # @ac "AC-006"
    test "edit/5 bypasses internal-link validation for external adaptive iframe sources", %{
      author: author,
      project: project,
      revision1: revision
    } do
      {:ok, {%{resource_id: activity_resource_id}, _}} =
        ActivityEditor.create(project.slug, "oli_adaptive", author, %{}, [])

      update = %{
        "content" => %{
          "authoring" => %{
            "parts" => [
              %{
                "id" => "part-iframe-1",
                "type" => "janus-capi-iframe",
                "src" => "https://example.com",
                "sourceType" => "url"
              }
            ]
          }
        }
      }

      PageEditor.acquire_lock(project.slug, revision.slug, author.email)

      assert {:ok, updated_revision} =
               ActivityEditor.edit(
                 project.slug,
                 revision.resource_id,
                 activity_resource_id,
                 author.email,
                 update
               )

      [part] = get_in(updated_revision.content, ["authoring", "parts"])
      assert part["src"] == "https://example.com"
      refute Map.has_key?(part, "idref")
      refute Map.has_key?(part, "resource_id")
      refute Map.has_key?(part, "linkType")
    end
  end

  defp attach_telemetry(events) do
    handler_id = "adaptive-authoring-telemetry-test-#{System.unique_integer([:positive])}"
    parent = self()

    telemetry_events =
      Enum.map(events, fn event ->
        [:oli, :adaptive, :dynamic_link, event]
      end)

    :ok =
      :telemetry.attach_many(
        handler_id,
        telemetry_events,
        fn event_name, measurements, metadata, _config ->
          send(parent, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

    handler_id
  end
end
