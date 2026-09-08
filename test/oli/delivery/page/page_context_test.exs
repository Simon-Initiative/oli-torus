defmodule Oli.Delivery.Page.PageContextTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Page.PageContext
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections

  describe "page context" do
    setup do
      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)

      o = Map.get(map, :o1).revision.resource_id

      map =
        Seeder.add_activity(
          map,
          %{title: "one", objectives: %{"1" => [o]}, content: content},
          :a1
        )
        |> Seeder.add_activity(
          %{
            title: "two",
            content: %{
              "stem" => "3",
              "authoring" => %{"parts" => [%{"id" => "1", "responses" => []}]}
            }
          },
          :a2
        )
        |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a1).resource.id},
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a2).resource.id}
          ]
        },
        objectives: %{"attached" => [o]}
      }

      Seeder.ensure_published(map.publication.id)

      Seeder.add_page(map, attrs, :p1)
      |> Seeder.create_section_resources()
    end

    test "create_context/2 returns the activities mapped correctly",
         %{
           section: section,
           p1: p1,
           a1: a1,
           user1: user,
           container: %{resource: container_resource, revision: container_revision}
         } = map do
      page1 = Map.get(map, :page1)
      page2 = Map.get(map, :page2)
      publication = Map.get(map, :publication)

      Seeder.replace_pages_with(
        [page1, %{id: p1.resource.id}, page2],
        container_resource,
        container_revision,
        publication
      )

      Seeder.rebuild_section_resources(%{section: section, publication: publication})

      datashop_session_id = UUID.uuid4()

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      context = PageContext.create_for_visit(section, p1.revision.slug, user, datashop_session_id)

      # verify activities map
      assert Map.get(context.activities, a1.resource.id).model != nil

      # verify objectives map
      assert context.objectives == ["objective one"]
      refute context.collab_space_config
    end

    test "inactive experiment placements realize only the first branch after one relevance read",
         %{section: section, p1: p1, a1: a1, a2: a2, user1: user} = map do
      alternatives_revision =
        insert(:revision,
          resource_type_id: Oli.Resources.ResourceType.id_for_alternatives(),
          content: %{
            "strategy" => "experiment_controlled",
            "options" => [%{"id" => "control"}, %{"id" => "variant"}]
          }
        )

      insert(:project_resource,
        project_id: map.project.id,
        resource_id: alternatives_revision.resource_id
      )

      insert(:published_resource,
        publication: map.publication,
        resource: alternatives_revision.resource,
        revision: alternatives_revision
      )

      insert(:section_resource,
        section: section,
        project: map.project,
        resource_id: alternatives_revision.resource_id
      )

      content = %{
        "model" => [
          %{
            "type" => "alternatives",
            "id" => "placement",
            "alternatives_id" => alternatives_revision.resource_id,
            "children" => [
              %{
                "type" => "alternative",
                "value" => "control",
                "children" => [
                  %{"type" => "activity-reference", "activity_id" => a1.resource.id}
                ]
              },
              %{
                "type" => "alternative",
                "value" => "variant",
                "children" => [
                  %{"type" => "activity-reference", "activity_id" => a2.resource.id}
                ]
              }
            ]
          }
        ]
      }

      p1.revision
      |> Oli.Resources.Revision.changeset(%{content: content})
      |> Repo.update!()

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      queries =
        capture_select_queries(fn ->
          context = PageContext.create_for_visit(section, p1.revision.slug, user, UUID.uuid4())

          assert Map.keys(context.activities) == [a1.resource.id]
          assert context.experiment_decisions["placement"].status == :no_experiment
        end)

      assert Enum.count(queries, &String.contains?(&1, ~s("experiment_sections"))) == 1
      refute Enum.any?(queries, &String.contains?(&1, ~s(FROM "experiment_assignments")))
      refute Enum.any?(queries, &String.contains?(&1, ~s(FROM "experiment_policy_states")))
    end
  end

  defp capture_select_queries(fun) do
    parent = self()
    handler_id = "page-context-selects-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:oli, :repo, :query],
      fn _, _, metadata, _ ->
        case metadata.query do
          "SELECT" <> _ = query -> send(parent, {:select_query, query})
          _ -> :ok
        end
      end,
      %{}
    )

    try do
      fun.()
      collect_select_queries([])
    after
      :telemetry.detach(handler_id)
    end
  end

  defp collect_select_queries(queries) do
    receive do
      {:select_query, query} -> collect_select_queries([query | queries])
    after
      0 -> queries
    end
  end
end
