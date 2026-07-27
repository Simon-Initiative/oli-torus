defmodule Oli.Delivery.LearningObjectives.PageElementTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.LearningObjectives.IncludedObjective
  alias Oli.Delivery.LearningObjectives.PageElement
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.PostProcessing
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Resources

  describe "prepare_render_payload/5" do
    setup [:create_delivery_project]

    test "returns nil without depot or objective work when no Learning Objectives element exists",
         %{
           seeds: %{section: section, resources: resources}
         } do
      assert PageElement.prepare_render_payload(
               section,
               resources.page_resource_2.id,
               %{"model" => []},
               insert(:user),
               schedule_fun: fn _ -> flunk("schedule should not be loaded") end,
               objectives_fun: fn _ -> flunk("objectives should not be loaded") end,
               activity_refs_fun: fn _ -> flunk("activity refs should not be loaded") end,
               proficiency_fun: fn _, _, _ -> flunk("proficiency should not be loaded") end
             ) == nil
    end

    test "ignores malformed nested Learning Objectives elements during the delivery pre-scan",
         %{
           seeds: %{section: section, resources: resources}
         } do
      assert PageElement.prepare_render_payload(
               section,
               resources.page_resource_2.id,
               %{
                 "model" => [
                   %{
                     "type" => "group",
                     "children" => [
                       %{
                         "type" => "learning_objectives",
                         "id" => "nested-lo",
                         "mode" => "summary"
                       }
                     ]
                   }
                 ]
               },
               insert(:user),
               schedule_fun: fn _ -> flunk("schedule should not be loaded") end
             ) == nil
    end

    test "uses the current page's most specific container", %{
      seeds: %{section: section, resources: resources}
    } do
      payload =
        PageElement.prepare_render_payload(
          section,
          resources.page_resource_2.id,
          learning_objectives_content("introduction"),
          insert(:user)
        )

      assert payload.container_resource_id == resources.module_resource_1.id

      assert Enum.map(payload.objectives, & &1.resource_id) == [
               resources.obj_resource_c.id,
               resources.obj_resource_c1.id,
               resources.obj_resource_d.id
             ]
    end

    test "uses the course root when a page has no non-root container", %{
      seeds: %{section: section, resources: resources}
    } do
      payload =
        PageElement.prepare_render_payload(
          section,
          resources.page_resource_1.id,
          learning_objectives_content("introduction"),
          insert(:user)
        )

      assert payload.container_resource_id == resources.root_resource.id

      payload_ids = MapSet.new(Enum.map(payload.objectives, & &1.resource_id))
      assert MapSet.member?(payload_ids, resources.obj_resource_c.id)
      assert MapSet.member?(payload_ids, resources.obj_resource_d.id)
      assert MapSet.member?(payload_ids, resources.obj_resource_e.id)
      assert MapSet.member?(payload_ids, resources.obj_resource_f.id)

      refute MapSet.member?(payload_ids, resources.obj_resource_a.id)
      refute MapSet.member?(payload_ids, resources.obj_resource_b.id)
    end

    test "tolerates stale advisory config and includes newly discovered objectives", %{
      seeds: %{section: section, resources: resources}
    } do
      payload =
        PageElement.prepare_render_payload(
          section,
          resources.page_resource_2.id,
          learning_objectives_content("summary", [
            %{
              "resource_id" => 999_999,
              "enabled" => false,
              "revisit_pages" => [123],
              "practice_pages" => [456]
            }
          ]),
          insert(:user)
        )

      payload_ids = MapSet.new(Enum.map(payload.objectives, & &1.resource_id))

      refute MapSet.member?(payload_ids, 999_999)
      assert MapSet.member?(payload_ids, resources.obj_resource_c.id)
      assert MapSet.member?(payload_ids, resources.obj_resource_c1.id)
      assert MapSet.member?(payload_ids, resources.obj_resource_d.id)
    end

    test "queries proficiency only when a Summary element exists", %{
      seeds: %{section: section, resources: resources}
    } do
      parent = self()
      user = insert(:user)

      PageElement.prepare_render_payload(
        section,
        resources.page_resource_2.id,
        learning_objectives_content("introduction"),
        user,
        proficiency_fun: fn _, _, _ ->
          send(parent, :unexpected_proficiency)
          %{}
        end
      )

      refute_received :unexpected_proficiency

      payload =
        PageElement.prepare_render_payload(
          section,
          resources.page_resource_2.id,
          learning_objectives_content("summary"),
          user,
          proficiency_fun: fn section_id, objective_ids, student_id: student_id ->
            send(parent, {:proficiency, section_id, objective_ids, student_id})
            Map.new(objective_ids, &{&1, %{student_id => "High"}})
          end
        )

      assert_received {:proficiency, section_id, objective_ids, student_id}
      assert section_id == section.id
      assert student_id == user.id
      assert Enum.sort(objective_ids) == Enum.sort(Enum.map(payload.objectives, & &1.resource_id))

      assert Enum.all?(payload.performance_by_objective_id, fn {_objective_id, value} ->
               value == "High"
             end)
    end

    test "does not query proficiency without a delivery user", %{
      seeds: %{section: section, resources: resources}
    } do
      parent = self()

      Enum.each([nil, insert(:author)], fn non_delivery_user ->
        payload =
          PageElement.prepare_render_payload(
            section,
            resources.page_resource_2.id,
            learning_objectives_content("summary"),
            non_delivery_user,
            proficiency_fun: fn _, _, _ ->
              send(parent, :unexpected_proficiency)
              %{}
            end
          )

        assert payload.performance_by_objective_id == %{}
        refute_received :unexpected_proficiency
      end)
    end
  end

  describe "included_objectives/3" do
    setup [:create_delivery_project]

    test "returns activity-attached objectives from a container's non-hidden descendant pages", %{
      seeds: %{section: section, resources: resources}
    } do
      assert {:ok, objectives} =
               PageElement.included_objectives(section, resources.module_resource_1.id)

      assert Enum.map(objectives, & &1.resource_id) == [
               resources.obj_resource_c.id,
               resources.obj_resource_c1.id,
               resources.obj_resource_d.id
             ]

      refute Enum.any?(objectives, &(&1.resource_id == resources.obj_resource_a.id))
      refute Enum.any?(objectives, &(&1.resource_id == resources.obj_resource_b.id))
      refute Enum.any?(objectives, &(&1.resource_id == resources.obj_resource_e.id))
      refute Enum.any?(objectives, &(&1.resource_id == resources.obj_resource_f.id))
    end

    test "loads page activity refs through one narrow revision boundary", %{
      seeds: %{section: section, resources: resources, revisions: revisions}
    } do
      parent = self()

      assert {:ok, objectives} =
               PageElement.included_objectives(
                 section,
                 resources.module_resource_1.id,
                 activity_refs_fun: fn revision_ids ->
                   send(parent, {:activity_refs, revision_ids})

                   [
                     [resources.act_resource_y.id, resources.act_resource_z.id]
                   ]
                 end
               )

      assert_received {:activity_refs, [revision_id]}
      assert revision_id == revisions.page_revision_2.id
      refute_received {:activity_refs, _}

      assert Enum.map(objectives, & &1.resource_id) == [
               resources.obj_resource_c.id,
               resources.obj_resource_c1.id,
               resources.obj_resource_d.id
             ]
    end

    test "skips objective depot lookup when descendant pages have no activity refs", %{
      seeds: %{section: section, resources: resources}
    } do
      assert {:ok, []} =
               PageElement.included_objectives(
                 section,
                 resources.module_resource_1.id,
                 activity_refs_fun: fn _revision_ids -> [] end,
                 objectives_fun: fn _section_id ->
                   flunk("objectives should not be loaded without in-scope activity refs")
                 end
               )
    end

    test "excludes objectives found only on hidden descendant pages", %{
      seeds: %{section: section, resources: resources}
    } do
      page_3_sr =
        SectionResourceDepot.get_section_resource(section.id, resources.page_resource_3.id)

      {:ok, page_3_sr} = Sections.update_section_resource(page_3_sr, %{hidden: true})
      SectionResourceDepot.update_section_resource(page_3_sr)

      assert {:ok, objectives} =
               PageElement.included_objectives(section, resources.root_resource.id)

      objective_ids = MapSet.new(Enum.map(objectives, & &1.resource_id))
      assert MapSet.member?(objective_ids, resources.obj_resource_c.id)
      assert MapSet.member?(objective_ids, resources.obj_resource_d.id)
      refute MapSet.member?(objective_ids, resources.obj_resource_e.id)
      refute MapSet.member?(objective_ids, resources.obj_resource_f.id)
    end

    test "includes parent objectives before directly matched sub-objectives", %{
      seeds: %{section: section, resources: resources}
    } do
      force_related_activities(section, resources.obj_resource_c.id, [])

      force_related_activities(section, resources.obj_resource_c1.id, [
        resources.act_resource_y.id
      ])

      assert {:ok, objectives} =
               PageElement.included_objectives(section, resources.module_resource_1.id)

      parent = Enum.find(objectives, &(&1.resource_id == resources.obj_resource_c.id))
      child = Enum.find(objectives, &(&1.resource_id == resources.obj_resource_c1.id))

      assert %IncludedObjective{directly_matched?: false, related_activity_ids: []} = parent

      assert %IncludedObjective{
               directly_matched?: true,
               related_activity_ids: [activity_y_id],
               parent_resource_id: parent_id
             } = child

      assert activity_y_id == resources.act_resource_y.id
      assert parent_id == resources.obj_resource_c.id
      assert parent.children == [resources.obj_resource_c1.id]

      assert Enum.find_index(objectives, &(&1.resource_id == parent.resource_id)) <
               Enum.find_index(objectives, &(&1.resource_id == child.resource_id))
    end
  end

  defp create_delivery_project(_) do
    seeds = create_full_project_with_objectives()
    %{project: project, section: section, resources: resources, revisions: revisions} = seeds
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

    PostProcessing.apply(section, :related_activities)
    SectionResourceDepot.process_table_creation(section.id)

    {:ok, seeds: seeds}
  end

  defp learning_objectives_content(mode, configs \\ []) do
    %{
      "model" => [
        %{
          "type" => "learning_objectives",
          "id" => "lo-1",
          "mode" => mode,
          "include_sub_objectives" => true,
          "learning_objectives" => configs
        }
      ]
    }
  end

  defp force_related_activities(section, objective_resource_id, activity_resource_ids) do
    section.id
    |> SectionResourceDepot.get_section_resource(objective_resource_id)
    |> Sections.update_section_resource(%{related_activities: activity_resource_ids})
    |> case do
      {:ok, section_resource} ->
        SectionResourceDepot.update_section_resource(section_resource)
        section_resource
    end
  end
end
