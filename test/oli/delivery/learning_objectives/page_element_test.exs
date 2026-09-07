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
               raw_proficiency_fun: fn _, _, _ -> flunk("proficiency should not be loaded") end
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
        raw_proficiency_fun: fn _, _, _ ->
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
          raw_proficiency_fun: fn section_id, resource_ids, student_id: student_id ->
            send(parent, {:proficiency, section_id, resource_ids, student_id})
            Map.new(resource_ids, &{&1, %{student_id => {1.0, 5}}})
          end
        )

      assert_received {:proficiency, section_id, resource_ids, student_id}
      assert section_id == section.id
      assert student_id == user.id

      # obj_resource_c has obj_resource_c1 as its only Sub-LO, so its evidence
      # is fetched for both obj_resource_c's own resource_id and
      # obj_resource_c1's; obj_resource_c1 and obj_resource_d are leaves, so
      # each fetches only its own evidence. A parent's own resource_id is
      # always requested alongside its Sub-LOs' (Option B — see
      # Metrics.evidence_resource_ids/2).
      assert Enum.sort(resource_ids) ==
               Enum.sort([
                 resources.obj_resource_c.id,
                 resources.obj_resource_c1.id,
                 resources.obj_resource_d.id
               ])

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
            raw_proficiency_fun: fn _, _, _ ->
              send(parent, :unexpected_proficiency)
              %{}
            end
          )

        assert payload.performance_by_objective_id == %{}
        refute_received :unexpected_proficiency
      end)
    end

    test "combines a parent's own evidence with a Sub-LO's evidence, including a Sub-LO outside this page element's own scope, consistent with the Instructor Dashboard",
         %{
           seeds: %{section: section, resources: resources, revisions: revisions}
         } do
      user = insert(:user)
      objective_type_id = Resources.ResourceType.id_for_objective()

      # Give obj_resource_d a Sub-LO (obj_resource_e) that has no activity on
      # page_resource_2: page_resource_2's own render scope will not include
      # E, but E's evidence must still be combined into D's aggregated
      # proficiency, consistent with the Instructor Dashboard (Phase 3).
      #
      # Set via the revision's `children` (resource ids), not the
      # SectionResource-level `children` (section_resource ids, per
      # Sections.populate_children_for_objectives/4) that `force_children`
      # sets — Sections.get_objectives_and_subobjectives/2 and
      # SectionResourceDepot.objectives_with_effective_children/1 only agree
      # on the same resolved children when the SectionResource's own
      # `children` is empty and both fall back to reading the revision.
      {:ok, _} =
        revisions.obj_revision_d
        |> Ecto.Changeset.change(children: [resources.obj_resource_e.id])
        |> Oli.Repo.update()

      # D's own directly-tagged evidence (from Activity Z) is always combined
      # with its Sub-LO's evidence, per a deliberate product decision (Darren
      # Siegel, Slack, 2026-09-01, "Option B" in
      # docs/exec-plans/current/epics/learning_model_v2/lo_aggregation/parent_evidence_aggregation_options.md).
      insert(:resource_summary, %{
        project_id: -1,
        section_id: section.id,
        user_id: user.id,
        resource_id: resources.obj_resource_d.id,
        resource_type_id: objective_type_id,
        part_id: "unknown",
        num_correct: 5,
        num_attempts: 5,
        num_hints: 0,
        num_first_attempts: 5,
        num_first_attempts_correct: 5
      })

      # obj_resource_e's evidence combines with D's own evidence above.
      insert(:resource_summary, %{
        project_id: -1,
        section_id: section.id,
        user_id: user.id,
        resource_id: resources.obj_resource_e.id,
        resource_type_id: objective_type_id,
        part_id: "unknown",
        num_correct: 0,
        num_attempts: 4,
        num_hints: 0,
        num_first_attempts: 4,
        num_first_attempts_correct: 0
      })

      payload =
        PageElement.prepare_render_payload(
          section,
          resources.page_resource_2.id,
          learning_objectives_content("summary"),
          user
        )

      # obj_resource_e is not directly matched on page_resource_2 and is not
      # an ancestor of anything that is, so it is not rendered here — only D
      # is.
      refute Enum.any?(payload.objectives, &(&1.resource_id == resources.obj_resource_e.id))
      assert Enum.any?(payload.objectives, &(&1.resource_id == resources.obj_resource_d.id))

      page_element_proficiency =
        Map.fetch!(payload.performance_by_objective_id, resources.obj_resource_d.id)

      # (1.0*5 + 0.2*4) / (5+4) = 5.8/9 = 0.644 => "Medium". If E's
      # out-of-scope evidence were dropped, this would be "High" (D's own
      # evidence alone) instead.
      assert page_element_proficiency == "Medium"

      dashboard_result =
        Sections.get_objectives_and_subobjectives(section, student_id: user.id)
        |> Enum.find(&(&1.objective_resource_id == resources.obj_resource_d.id))

      assert dashboard_result.student_proficiency_obj == page_element_proficiency
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

    test "includes every parent hierarchy for a shared directly matched sub-objective", %{
      seeds: %{section: section, resources: resources}
    } do
      force_children(section, resources.obj_resource_d.id, [resources.obj_resource_c1.id])
      force_related_activities(section, resources.obj_resource_c.id, [])
      force_related_activities(section, resources.obj_resource_d.id, [])

      force_related_activities(section, resources.obj_resource_c1.id, [
        resources.act_resource_y.id
      ])

      assert {:ok, objectives} =
               PageElement.included_objectives(section, resources.module_resource_1.id)

      parent_c = Enum.find(objectives, &(&1.resource_id == resources.obj_resource_c.id))
      parent_d = Enum.find(objectives, &(&1.resource_id == resources.obj_resource_d.id))
      child = Enum.find(objectives, &(&1.resource_id == resources.obj_resource_c1.id))

      refute parent_c.directly_matched?
      refute parent_d.directly_matched?
      assert child.directly_matched?

      assert parent_c.children == [resources.obj_resource_c1.id]
      assert parent_d.children == [resources.obj_resource_c1.id]

      assert Enum.sort(child.parent_resource_ids) == [
               resources.obj_resource_c.id,
               resources.obj_resource_d.id
             ]

      assert Enum.find_index(objectives, &(&1.resource_id == parent_c.resource_id)) <
               Enum.find_index(objectives, &(&1.resource_id == child.resource_id))

      assert Enum.find_index(objectives, &(&1.resource_id == parent_d.resource_id)) <
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

  defp force_children(section, objective_resource_id, child_resource_ids) do
    section.id
    |> SectionResourceDepot.get_section_resource(objective_resource_id)
    |> Sections.update_section_resource(%{children: child_resource_ids})
    |> case do
      {:ok, section_resource} ->
        SectionResourceDepot.update_section_resource(section_resource)
        section_resource
    end
  end
end
