defmodule Oli.Authoring.LearningObjectives.PageElementTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.LearningObjectives.PageElement
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources

  describe "resolve/4" do
    setup do
      seeds = create_full_project_with_objectives()

      %{project: project, resources: resources, revisions: revisions} = seeds
      author = hd(project.authors)

      {:ok, _} =
        Resources.update_revision(revisions.page_revision_1, %{
          author_id: author.id,
          activity_refs: [resources.act_resource_x.id]
        })

      {:ok, _} =
        Resources.update_revision(revisions.page_revision_2, %{
          author_id: author.id,
          activity_refs: [resources.act_resource_y.id, resources.act_resource_z.id]
        })

      {:ok, _} =
        Resources.update_revision(revisions.page_revision_3, %{
          author_id: author.id,
          activity_refs: [revisions.act_revision_w.resource_id]
        })

      {:ok, _} =
        Resources.update_revision(revisions.act_revision_y, %{
          author_id: author.id,
          objectives: %{"1" => [resources.obj_resource_c1.id]}
        })

      {:ok, seeds: seeds}
    end

    test "returns activity-attached objectives from the current container recursively", %{
      seeds: seeds
    } do
      %{project: project, publication: publication, resources: resources} = seeds

      resolved =
        resolve_for_page(project.slug, publication.id, resources.page_resource_2.id)

      assert Enum.map(resolved, & &1.resource_id) == [
               resources.obj_resource_c.id,
               resources.obj_resource_c1.id,
               resources.obj_resource_d.id
             ]

      refute Enum.any?(resolved, &(&1.resource_id == resources.obj_resource_a.id))
      refute Enum.any?(resolved, &(&1.resource_id == resources.obj_resource_b.id))
      refute Enum.any?(resolved, &(&1.resource_id == resources.obj_resource_e.id))
      refute Enum.any?(resolved, &(&1.resource_id == resources.obj_resource_f.id))
    end

    test "includes parents before directly matched sub-objectives", %{seeds: seeds} do
      %{project: project, publication: publication, resources: resources} = seeds

      resolved =
        resolve_for_page(project.slug, publication.id, resources.page_resource_2.id)

      parent = Enum.find(resolved, &(&1.resource_id == resources.obj_resource_c.id))
      child = Enum.find(resolved, &(&1.resource_id == resources.obj_resource_c1.id))

      assert Enum.find_index(resolved, &(&1.resource_id == parent.resource_id)) <
               Enum.find_index(resolved, &(&1.resource_id == child.resource_id))

      refute parent.directly_matched
      assert parent.related_activity_ids == []

      assert child.parent_resource_id == parent.resource_id
      assert child.directly_matched
      assert child.related_activity_ids == [resources.act_resource_y.id]
    end

    test "includes every parent for a shared directly matched sub-objective", %{seeds: seeds} do
      %{project: project, publication: publication, resources: resources, revisions: revisions} =
        seeds

      author = hd(project.authors)

      {:ok, _} =
        Resources.update_revision(revisions.obj_revision_d, %{
          author_id: author.id,
          children: [resources.obj_resource_c1.id]
        })

      resolved =
        resolve_for_page(project.slug, publication.id, resources.page_resource_2.id)

      included_ids =
        resolved
        |> Enum.map(& &1.resource_id)

      child = Enum.find(resolved, &(&1.resource_id == resources.obj_resource_c1.id))

      assert resources.obj_resource_c.id in included_ids
      assert resources.obj_resource_d.id in included_ids

      assert Enum.sort(child.parent_resource_ids) == [
               resources.obj_resource_c.id,
               resources.obj_resource_d.id
             ]
    end

    test "does not leak objectives from another project", %{seeds: seeds} do
      other_project = create_full_project_with_objectives()
      %{project: project, publication: publication, resources: resources} = seeds

      resolved =
        resolve_for_page(project.slug, publication.id, resources.page_resource_2.id)

      resolved_ids = MapSet.new(Enum.map(resolved, & &1.resource_id))

      other_project.resources
      |> Map.take([
        :obj_resource_a,
        :obj_resource_b,
        :obj_resource_c,
        :obj_resource_c1,
        :obj_resource_d,
        :obj_resource_e,
        :obj_resource_f
      ])
      |> Map.values()
      |> Enum.each(fn resource ->
        refute MapSet.member?(resolved_ids, resource.id)
      end)
    end
  end

  describe "page editor context" do
    test "returns resolved learning objectives only when the page contains the element" do
      seeds = create_full_project_with_objectives()
      %{project: project, resources: resources, revisions: revisions} = seeds
      author = hd(project.authors)

      {:ok, _} =
        Resources.update_revision(revisions.page_revision_2, %{
          author_id: author.id,
          activity_refs: [resources.act_resource_y.id],
          content: %{
            "version" => "0.1.0",
            "model" => [
              %{
                "type" => "learning_objectives",
                "id" => "lo-1",
                "mode" => "introduction",
                "include_sub_objectives" => true,
                "learning_objectives" => []
              }
            ]
          }
        })

      {:ok, context} =
        PageEditor.create_context(project.slug, revisions.page_revision_2.slug, author)

      assert Enum.map(context.learningObjectives, & &1.resource_id) == [
               resources.obj_resource_c.id,
               resources.obj_resource_c1.id
             ]

      {:ok, context_without_element} =
        PageEditor.create_context(project.slug, revisions.page_revision_1.slug, author)

      assert context_without_element.learningObjectives == []
    end

    test "filters learning objective recommendation ids to current project pages" do
      seeds = create_full_project_with_objectives()

      %{project: project, resources: resources, revisions: revisions} = seeds
      author = hd(project.authors)

      valid_page_id = resources.page_resource_1.id
      objective_id = resources.obj_resource_a.id
      other_project_page_id = out_of_project_page_id(author)

      PageEditor.acquire_lock(project.slug, revisions.page_revision_2.slug, author.email)

      content = %{
        "version" => "0.1.0",
        "model" =>
          [
            %{
              "type" => "learning_objectives",
              "id" => "lo-1",
              "mode" => "summary",
              "include_sub_objectives" => true,
              "learning_objectives" => [
                %{
                  "resource_id" => resources.obj_resource_c.id,
                  "enabled" => true,
                  "revisit_pages" => [valid_page_id, objective_id, other_project_page_id],
                  "practice_pages" => [other_project_page_id, valid_page_id, valid_page_id]
                }
              ]
            }
          ] ++
            [
              %{
                "type" => "activity-reference",
                "id" => "activity-y",
                "activitySlug" => revisions.act_revision_y.slug,
                "children" => []
              },
              %{
                "type" => "activity-reference",
                "id" => "activity-z",
                "activitySlug" => revisions.act_revision_z.slug,
                "children" => []
              }
            ]
      }

      assert {:ok, updated_revision} =
               PageEditor.edit(project.slug, revisions.page_revision_2.slug, author.email, %{
                 "content" => content
               })

      [element | _activity_references] = updated_revision.content["model"]
      [config] = element["learning_objectives"]

      assert config["revisit_pages"] == [valid_page_id]
      assert config["practice_pages"] == [valid_page_id]
    end

    test "treats malformed learning objectives config as an empty list" do
      seeds = create_full_project_with_objectives()

      %{project: project, revisions: revisions} = seeds
      author = hd(project.authors)

      PageEditor.acquire_lock(project.slug, revisions.page_revision_2.slug, author.email)

      content = %{
        "version" => "0.1.0",
        "model" =>
          [
            %{
              "type" => "learning_objectives",
              "id" => "lo-1",
              "mode" => "summary",
              "include_sub_objectives" => true,
              "learning_objectives" => "not-a-list"
            }
          ] ++ activity_references(revisions)
      }

      assert {:ok, updated_revision} =
               PageEditor.edit(project.slug, revisions.page_revision_2.slug, author.email, %{
                 "content" => content
               })

      [element | _activity_references] = updated_revision.content["model"]

      assert element["learning_objectives"] == []
    end

    test "treats malformed learning objective recommendation fields as empty lists" do
      seeds = create_full_project_with_objectives()

      %{project: project, resources: resources, revisions: revisions} = seeds
      author = hd(project.authors)

      PageEditor.acquire_lock(project.slug, revisions.page_revision_2.slug, author.email)

      content = %{
        "version" => "0.1.0",
        "model" =>
          [
            %{
              "type" => "learning_objectives",
              "id" => "lo-1",
              "mode" => "summary",
              "include_sub_objectives" => true,
              "learning_objectives" => [
                %{
                  "resource_id" => resources.obj_resource_c.id,
                  "enabled" => true,
                  "revisit_pages" => "not-a-list",
                  "practice_pages" => %{"bad" => "shape"}
                }
              ]
            }
          ] ++ activity_references(revisions)
      }

      assert {:ok, updated_revision} =
               PageEditor.edit(project.slug, revisions.page_revision_2.slug, author.email, %{
                 "content" => content
               })

      [element | _activity_references] = updated_revision.content["model"]
      [config] = element["learning_objectives"]

      assert config["revisit_pages"] == []
      assert config["practice_pages"] == []
    end
  end

  defp resolve_for_page(project_slug, publication_id, page_resource_id) do
    hierarchy = AuthoringResolver.full_hierarchy(project_slug)
    objectives = Publishing.get_published_objective_details(publication_id)

    PageElement.resolve(project_slug, page_resource_id, hierarchy, objectives)
  end

  defp activity_references(revisions) do
    [
      %{
        "type" => "activity-reference",
        "id" => "activity-y",
        "activitySlug" => revisions.act_revision_y.slug,
        "children" => []
      },
      %{
        "type" => "activity-reference",
        "id" => "activity-z",
        "activitySlug" => revisions.act_revision_z.slug,
        "children" => []
      }
    ]
  end

  defp out_of_project_page_id(author) do
    other_project = insert(:project, authors: [author])
    page_resource = insert(:resource)

    page_revision =
      insert(:revision, %{
        author: author,
        resource: page_resource,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        slug: "out_of_project_page_#{System.unique_integer([:positive])}",
        deleted: false
      })

    insert(:project_resource, %{project_id: other_project.id, resource_id: page_resource.id})

    publication =
      insert(:publication, %{
        project: other_project,
        root_resource_id: page_resource.id,
        published: nil
      })

    insert(:published_resource, %{
      author: author,
      publication: publication,
      resource: page_resource,
      revision: page_revision
    })

    page_resource.id
  end
end
