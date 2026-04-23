defmodule Oli.Authoring.Editing.AdaptiveDuplicationTest do
  use Oli.DataCase

  alias Oli.Activities
  alias Oli.Authoring.Course.ProjectResource
  alias Oli.Authoring.Editing.AdaptiveDuplication
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.ScopedFeatureFlags.Rollouts
  alias Oli.Seeder

  describe "extract_adaptive_screen_refs/1" do
    test "returns ordered screen refs with preserved sequence metadata" do
      content = %{
        "advancedDelivery" => true,
        "model" => [
          %{
            "type" => "group",
            "layout" => "deck",
            "children" => [
              %{
                "type" => "activity-reference",
                "activity_id" => 11,
                "custom" => %{"sequenceId" => "screen-1", "sequenceName" => "Screen 1"}
              },
              %{
                "type" => "activity-reference",
                "activity_id" => 11,
                "custom" => %{"sequenceId" => "screen-2", "sequenceName" => "Screen 2"}
              },
              %{
                "type" => "activity-reference",
                "activity_id" => 22,
                "custom" => %{"sequenceId" => "screen-3", "sequenceName" => "Screen 3"}
              }
            ]
          }
        ]
      }

      assert {:ok, screen_refs} = AdaptiveDuplication.extract_adaptive_screen_refs(content)

      assert screen_refs == [
               %{activity_id: 11, sequence_id: "screen-1", sequence_name: "Screen 1"},
               %{activity_id: 11, sequence_id: "screen-2", sequence_name: "Screen 2"},
               %{activity_id: 22, sequence_id: "screen-3", sequence_name: "Screen 3"}
             ]

      assert AdaptiveDuplication.screen_resource_ids(screen_refs) == [11, 22]
    end

    test "fails closed when the content is not an adaptive deck page" do
      assert {:error, {:adaptive_duplication, :not_adaptive_page}} =
               AdaptiveDuplication.extract_adaptive_screen_refs(%{"model" => []})

      assert {:error, {:adaptive_duplication, :missing_deck_group}} =
               AdaptiveDuplication.extract_adaptive_screen_refs(%{
                 "advancedDelivery" => true,
                 "model" => [%{"type" => "content"}]
               })
    end
  end

  describe "duplicate_screen_resources/3" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "duplicates adaptive screen resources and returns deterministic mappings", %{
      project: project,
      publication: publication,
      author: author
    } do
      screen_revisions =
        [
          {"Screen A", screen_content("screen-a")},
          {"Screen B", screen_content("screen-b")},
          {"Screen C", screen_content("screen-c")}
        ]
        |> Enum.map(fn {title, content} ->
          Seeder.create_activity(
            %{
              title: title,
              activity_type_id: Activities.get_registration_by_slug("oli_adaptive").id,
              content: content
            },
            publication,
            project,
            author
          ).revision
        end)

      original_project_resource_count = count_project_resources(project.id)
      original_published_resource_count = count_published_resources(project.id)

      assert {:ok, duplication} =
               AdaptiveDuplication.duplicate_screen_resources(project, screen_revisions, author)

      assert length(duplication.duplicated_resource_ids) == 3
      assert length(duplication.duplicated_revision_ids) == 3
      assert map_size(duplication.screen_resource_map) == 3
      assert map_size(duplication.screen_revision_map) == 3

      duplicated_revisions =
        from(r in Revision, where: r.resource_id in ^duplication.duplicated_resource_ids)
        |> Repo.all()
        |> Map.new(&{&1.resource_id, &1})

      Enum.each(screen_revisions, fn source_revision ->
        duplicated_resource_id = duplication.screen_resource_map[source_revision.resource_id]
        duplicated_revision_id = duplication.screen_revision_map[source_revision.resource_id]
        duplicated_revision = Map.fetch!(duplicated_revisions, duplicated_resource_id)

        refute duplicated_resource_id == source_revision.resource_id
        assert duplicated_revision.id == duplicated_revision_id
        assert duplicated_revision.title == source_revision.title
        assert duplicated_revision.content == source_revision.content
        assert duplicated_revision.objectives == source_revision.objectives
        assert duplicated_revision.activity_type_id == source_revision.activity_type_id
        assert duplicated_revision.resource_type_id == source_revision.resource_type_id
        assert duplicated_revision.author_id == author.id
        assert duplicated_revision.previous_revision_id == nil
      end)

      assert count_project_resources(project.id) == original_project_resource_count + 3
      assert count_published_resources(project.id) == original_published_resource_count + 3

      original_revisions =
        from(r in Revision, where: r.id in ^Enum.map(screen_revisions, & &1.id))
        |> Repo.all()
        |> Map.new(&{&1.id, &1})

      Enum.each(screen_revisions, fn source_revision ->
        assert Map.fetch!(original_revisions, source_revision.id).content ==
                 source_revision.content
      end)
    end
  end

  describe "remap_adaptive_screen_content/2" do
    test "rewires duplicated screen references across adaptive content surfaces" do
      content =
        screen_content("source-screen",
          destination_screen_id: 22,
          evaluation_activity_ids: [22, "44"],
          nested_activity_id: 22,
          nested_link_idref: "22",
          nested_iframe_resource_id: 44
        )

      remapped =
        AdaptiveDuplication.remap_adaptive_screen_content(content, %{
          22 => 122,
          44 => 144
        })

      assert get_in(remapped, ["authoring", "flowchart", "paths"]) == [
               %{"id" => "path-1", "destinationScreenId" => 122}
             ]

      assert get_in(remapped, ["authoring", "activitiesRequiredForEvaluation"]) == [122, 144]

      assert get_in(remapped, [
               "authoring",
               "rules",
               Access.at(0),
               "children",
               Access.at(0),
               "activity_id"
             ]) ==
               122

      assert get_in(remapped, [
               "authoring",
               "parts",
               Access.at(0),
               "custom",
               "nodes",
               Access.at(0),
               "idref"
             ]) ==
               122

      assert get_in(remapped, [
               "partsLayout",
               Access.at(0),
               "custom",
               "nodes",
               Access.at(1),
               "resource_id"
             ]) ==
               144
    end
  end

  describe "duplicate/3 transaction behavior" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "fails before duplication when a referenced screen revision cannot be resolved", %{
      project: project,
      publication: publication,
      author: author,
      container: %{revision: container_revision}
    } do
      {:ok, _} = Rollouts.upsert_rollout(:adaptive_duplication, :global, nil, :full, author)

      %{resource: adaptive_page_resource} =
        Seeder.create_page(
          "Broken Adaptive Page",
          publication,
          project,
          author,
          adaptive_page_content([
            %{activity_id: 999_999, sequence_id: "screen-1", sequence_name: "Screen 1"}
          ])
        )

      original_project_resource_count = count_project_resources(project.id)
      original_published_resource_count = count_published_resources(project.id)

      assert {:error, {:adaptive_duplication, :missing_screen_revision}} =
               AdaptiveDuplication.duplicate(project, adaptive_page_resource.id,
                 author: author,
                 container: container_revision
               )

      assert count_project_resources(project.id) == original_project_resource_count
      assert count_published_resources(project.id) == original_published_resource_count
    end

    test "duplicates screens and page, remaps duplicated content, and attaches the duplicated page",
         %{
           project: project,
           publication: publication,
           author: author,
           container: %{revision: container_revision}
         } do
      {:ok, _} = Rollouts.upsert_rollout(:adaptive_duplication, :global, nil, :full, author)

      %{revision: screen_two_revision} =
        Seeder.create_activity(
          %{
            title: "Screen 2",
            activity_type_id: Activities.get_registration_by_slug("oli_adaptive").id,
            content: screen_content("screen-2")
          },
          publication,
          project,
          author
        )

      %{revision: screen_one_revision} =
        Seeder.create_activity(
          %{
            title: "Screen 1",
            activity_type_id: Activities.get_registration_by_slug("oli_adaptive").id,
            content:
              screen_content("screen-1",
                destination_screen_id: screen_two_revision.resource_id,
                evaluation_activity_ids: [screen_two_revision.resource_id],
                nested_activity_id: screen_two_revision.resource_id,
                nested_link_idref: Integer.to_string(screen_two_revision.resource_id),
                nested_iframe_resource_id: screen_two_revision.resource_id
              )
          },
          publication,
          project,
          author
        )

      %{resource: adaptive_page_resource} =
        Seeder.create_page(
          "Source Adaptive Page",
          publication,
          project,
          author,
          adaptive_page_content([
            %{
              activity_id: screen_one_revision.resource_id,
              sequence_id: "screen-1",
              sequence_name: "Screen 1"
            },
            %{
              activity_id: screen_two_revision.resource_id,
              sequence_id: "screen-2",
              sequence_name: "Screen 2"
            }
          ])
        )

      original_project_resource_count = count_project_resources(project.id)
      original_published_resource_count = count_published_resources(project.id)

      assert {:ok, duplicated_page_revision} =
               AdaptiveDuplication.duplicate(project, adaptive_page_resource.id,
                 author: author,
                 container: container_revision
               )

      assert duplicated_page_revision.title == "Source Adaptive Page (copy)"
      assert duplicated_page_revision.resource_id != adaptive_page_resource.id

      assert count_project_resources(project.id) == original_project_resource_count + 3
      assert count_published_resources(project.id) == original_published_resource_count + 3

      updated_container =
        AuthoringResolver.from_resource_id(project.slug, container_revision.resource_id)

      assert List.last(updated_container.children) == duplicated_page_revision.resource_id

      duplicated_screen_ids =
        duplicated_page_revision.content["model"]
        |> Enum.at(0)
        |> Map.fetch!("children")
        |> Enum.map(& &1["activity_id"])

      assert length(duplicated_screen_ids) == 2
      refute Enum.member?(duplicated_screen_ids, screen_one_revision.resource_id)
      refute Enum.member?(duplicated_screen_ids, screen_two_revision.resource_id)

      [duplicated_screen_one, duplicated_screen_two] =
        Publishing.get_unpublished_revisions(project, duplicated_screen_ids)

      assert get_in(duplicated_page_revision.content, [
               "model",
               Access.at(0),
               "children",
               Access.at(0),
               "custom"
             ]) == %{"sequenceId" => "screen-1", "sequenceName" => "Screen 1"}

      assert get_in(duplicated_page_revision.content, [
               "model",
               Access.at(0),
               "children",
               Access.at(1),
               "custom"
             ]) == %{"sequenceId" => "screen-2", "sequenceName" => "Screen 2"}

      assert get_in(duplicated_screen_one.content, ["authoring", "flowchart", "paths"]) == [
               %{"id" => "path-1", "destinationScreenId" => duplicated_screen_two.resource_id}
             ]

      assert get_in(duplicated_screen_one.content, [
               "authoring",
               "activitiesRequiredForEvaluation"
             ]) == [
               duplicated_screen_two.resource_id
             ]

      assert get_in(duplicated_screen_one.content, [
               "authoring",
               "rules",
               Access.at(0),
               "children",
               Access.at(0),
               "activity_id"
             ]) == duplicated_screen_two.resource_id

      assert get_in(duplicated_screen_one.content, [
               "authoring",
               "parts",
               Access.at(0),
               "custom",
               "nodes",
               Access.at(0),
               "idref"
             ]) == duplicated_screen_two.resource_id

      assert get_in(duplicated_screen_one.content, [
               "partsLayout",
               Access.at(0),
               "custom",
               "nodes",
               Access.at(1),
               "resource_id"
             ]) == duplicated_screen_two.resource_id

      assert get_in(screen_one_revision.content, ["authoring", "flowchart", "paths"]) == [
               %{"id" => "path-1", "destinationScreenId" => screen_two_revision.resource_id}
             ]

      edited_duplicated_content =
        put_in(
          duplicated_screen_one.content,
          [
            "partsLayout",
            Access.at(0),
            "custom",
            "nodes",
            Access.at(0),
            "children",
            Access.at(0),
            "children",
            Access.at(0),
            "text"
          ],
          "duplicated screen edited"
        )

      assert {:ok, _updated_duplicated_screen} =
               Oli.Resources.update_revision(duplicated_screen_one, %{
                 content: edited_duplicated_content
               })

      original_screen_one =
        Repo.get!(Revision, screen_one_revision.id)

      duplicated_screen_one_after_edit =
        Repo.get!(Revision, duplicated_screen_one.id)

      assert get_in(original_screen_one.content, [
               "partsLayout",
               Access.at(0),
               "custom",
               "nodes",
               Access.at(0),
               "children",
               Access.at(0),
               "children",
               Access.at(0),
               "text"
             ]) == "screen-1"

      assert get_in(duplicated_screen_one_after_edit.content, [
               "partsLayout",
               Access.at(0),
               "custom",
               "nodes",
               Access.at(0),
               "children",
               Access.at(0),
               "children",
               Access.at(0),
               "text"
             ]) == "duplicated screen edited"
    end
  end

  defp adaptive_page_content(screen_refs) do
    %{
      "advancedAuthoring" => true,
      "advancedDelivery" => true,
      "displayApplicationChrome" => false,
      "model" => [
        %{
          "id" => "deck-root",
          "type" => "group",
          "layout" => "deck",
          "children" =>
            Enum.map(screen_refs, fn %{
                                       activity_id: activity_id,
                                       sequence_id: sequence_id,
                                       sequence_name: sequence_name
                                     } ->
              %{
                "id" => sequence_id,
                "type" => "activity-reference",
                "activity_id" => activity_id,
                "custom" => %{
                  "sequenceId" => sequence_id,
                  "sequenceName" => sequence_name
                }
              }
            end)
        }
      ]
    }
  end

  defp screen_content(prompt_text, opts \\ []) do
    destination_screen_id = Keyword.get(opts, :destination_screen_id)
    evaluation_activity_ids = Keyword.get(opts, :evaluation_activity_ids, [])
    nested_activity_id = Keyword.get(opts, :nested_activity_id)
    nested_link_idref = Keyword.get(opts, :nested_link_idref)
    nested_iframe_resource_id = Keyword.get(opts, :nested_iframe_resource_id)

    %{
      "authoring" =>
        %{
          "parts" => [
            %{
              "id" => "__default",
              "type" => "janus-text-flow",
              "owner" => "screen-owner",
              "inherited" => false,
              "custom" => %{
                "nodes" => [
                  %{
                    "tag" => "a",
                    "idref" => nested_link_idref,
                    "children" => [%{"tag" => "text", "text" => "Internal"}]
                  }
                ]
              }
            }
          ],
          "rules" =>
            if is_nil(nested_activity_id) do
              []
            else
              [
                %{
                  "id" => "rule-1",
                  "children" => [
                    %{"type" => "activity-reference", "activity_id" => nested_activity_id}
                  ]
                }
              ]
            end,
          "variablesRequiredForEvaluation" => [],
          "activitiesRequiredForEvaluation" => evaluation_activity_ids
        }
        |> maybe_put_flowchart(destination_screen_id),
      "partsLayout" => [
        %{
          "id" => "hello_world",
          "type" => "janus-text-flow",
          "custom" => %{
            "nodes" => [
              %{
                "tag" => "p",
                "children" => [
                  %{
                    "tag" => "span",
                    "style" => %{},
                    "children" => [
                      %{
                        "tag" => "text",
                        "text" => prompt_text,
                        "children" => []
                      }
                    ]
                  }
                ]
              },
              %{
                "type" => "janus-capi-iframe",
                "resource_id" => nested_iframe_resource_id,
                "sourceType" => "page",
                "linkType" => "page"
              }
            ]
          }
        }
      ]
    }
  end

  defp maybe_put_flowchart(authoring, nil), do: authoring

  defp maybe_put_flowchart(authoring, destination_screen_id) do
    Map.put(authoring, "flowchart", %{
      "paths" => [%{"id" => "path-1", "destinationScreenId" => destination_screen_id}]
    })
  end

  defp count_project_resources(project_id) do
    Repo.aggregate(
      from(pr in ProjectResource, where: pr.project_id == ^project_id),
      :count,
      :resource_id
    )
  end

  defp count_published_resources(project_id) do
    publication_id = Publishing.get_unpublished_publication_id!(project_id)

    Repo.aggregate(
      from(pr in PublishedResource, where: pr.publication_id == ^publication_id),
      :count,
      :id
    )
  end
end
