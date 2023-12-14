defmodule Oli.Delivery.SectionsTest do
  use OliWeb.ConnCase

  import Oli.Utils.Seeder.Utils

  alias Oli.Utils.Seeder
  alias Oli.Factory
  alias Oli.Delivery.Sections

  describe "sections" do
    setup(%{conn: conn}) do
      %{conn: conn}
      |> Seeder.Project.create_author(author_tag: :author)
      |> Seeder.Project.create_sample_project(
        ref(:author),
        project_tag: :proj,
        publication_tag: :pub,
        unscored_page1_tag: :unscored_page1,
        unscored_page1_activity_tag: :unscored_page1_activity,
        scored_page2_tag: :scored_page2,
        scored_page2_activity_tag: :scored_page2_activity
      )
      |> Seeder.Project.ensure_published(ref(:pub))
      |> Seeder.Section.create_section(
        ref(:proj),
        ref(:pub),
        nil,
        %{},
        section_tag: :section
      )
      |> Seeder.Section.create_and_enroll_learner(
        ref(:section),
        %{},
        user_tag: :student1
      )
    end

    test "opens section overview when there is a scheduled gating condition and end_datetime is nil",
         seeds do
      start_date = yesterday()
      end_date = nil

      %{conn: conn, section: section} =
        seeds
        |> Seeder.Section.create_schedule_gating_condition(
          ref(:section),
          ref(:unscored_page1),
          start_date,
          end_date
        )
        |> Seeder.Session.login_as_user(ref(:student1))
        |> Seeder.Section.ensure_user_visit(ref(:student1), ref(:section))

      conn =
        conn
        |> get(~p"/sections/#{section.slug}")

      assert html_response(conn, 200) =~ "Example Section"
    end
  end

  describe "rebuild_contained_objectives/1 for a section with objectives" do
    setup [:create_full_project_with_objectives]

    ## Course Hierarchy
    #
    # Root Container --> Page 1 --> Activity X
    #                |--> Unit Container --> Module Container 1 --> Page 2 --> Activity Y
    #                |                                                     |--> Activity Z
    #                |--> Module Container 2 --> Page 3 --> Activity W
    #
    ## Objectives Hierarchy
    #
    # Page 1 --> Objective A
    # Page 2 --> Objective B
    #
    # Note: the objectives above are not considered since they are attached to the pages
    #
    # Activity Y --> Objective C
    #           |--> SubObjective C1
    # Activity Z --> Objective D
    # Activity W --> Objective E
    #           |--> Objective F
    #
    # Note: Activity X does not have objectives
    test "it ignores objectives attached to inner pages", %{
      section: section,
      resources: resources
    } do
      assert {:ok, _} = Sections.rebuild_contained_objectives(section)

      # Check Root Container objectives
      root_container_objectives = Sections.get_section_contained_objectives(section.id, nil)

      # Objectives A and B are not attached
      [resources.obj_resource_a, resources.obj_resource_b]
      |> Enum.each(fn objective ->
        refute Enum.find(root_container_objectives, &(&1 == objective.id))
      end)

      assert Sections.get_section_by(slug: section.slug).v25_migration == :done
    end

    test "it creates contained objectives for each objective in the inner activities", %{
      section: section,
      resources: resources
    } do
      assert {:ok, _} = Sections.rebuild_contained_objectives(section)

      # Check Module Container 1 objectives
      module_container_1_objectives =
        Sections.get_section_contained_objectives(section.id, resources.module_resource_1.id)

      # C, C1 and D are the objectives attached to the inner activities
      assert length(module_container_1_objectives) == 3

      assert Enum.sort(module_container_1_objectives) ==
               Enum.sort([
                 resources.obj_resource_c.id,
                 resources.obj_resource_c1.id,
                 resources.obj_resource_d.id
               ])

      # Check Unit Container objectives
      unit_container_objectives =
        Sections.get_section_contained_objectives(section.id, resources.unit_resource.id)

      # C, C1 and D are the objectives attached to the inner activities
      assert length(unit_container_objectives) == 3

      assert Enum.sort(unit_container_objectives) ==
               Enum.sort([
                 resources.obj_resource_c.id,
                 resources.obj_resource_c1.id,
                 resources.obj_resource_d.id
               ])

      # Check Module Container 2 objectives
      module_container_2_objectives =
        Sections.get_section_contained_objectives(section.id, resources.module_resource_2.id)

      # E and F are the objectives attached to the inner activities
      assert length(module_container_2_objectives) == 2

      assert Enum.sort(module_container_2_objectives) ==
               Enum.sort([
                 resources.obj_resource_e.id,
                 resources.obj_resource_f.id
               ])

      # Check Root Container objectives
      root_container_objectives = Sections.get_section_contained_objectives(section.id, nil)

      # C, C1, D, E and F are the objectives attached to the inner activities
      assert length(root_container_objectives) == 5

      assert Enum.sort(root_container_objectives) ==
               Enum.sort([
                 resources.obj_resource_c.id,
                 resources.obj_resource_c1.id,
                 resources.obj_resource_d.id,
                 resources.obj_resource_e.id,
                 resources.obj_resource_f.id
               ])

      assert Sections.get_section_by(slug: section.slug).v25_migration == :done
    end
  end

  describe "rebuild_contained_objectives/1 for a section without objectives" do
    setup [:create_full_project_with_objectives]

    test "it does not insert any contained objective" do
      section = Factory.insert(:section)

      assert {:ok, _} = Sections.rebuild_contained_objectives(section)

      assert [] == Sections.get_section_contained_objectives(section.id, nil)
    end
  end

  describe "build_page_link_map/1" do
    setup(_) do
      %{}
      |> Seeder.Project.create_author(author_tag: :author)
      |> Seeder.Project.create_sample_project(
        ref(:author),
        project_tag: :proj,
        publication_tag: :pub,
        curriculum_revision_tag: :curriculum,
        unit1_tag: :unit1,
        unscored_page1_tag: :unscored_page1,
        unscored_page1_activity_tag: :unscored_page1_activity,
        scored_page2_tag: :scored_page2,
        scored_page2_activity_tag: :scored_page2_activity
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:proj),
        nil,
        %{},
        revision_tag: :non_hierarchical_page3
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:proj),
        nil,
        %{},
        revision_tag: :non_hierarchical_page5
      )
      |> Seeder.Project.edit_page(
        ref(:proj),
        ref(:scored_page2),
        refs([:non_hierarchical_page3], fn [non_hierarchical_page3] ->
          %{
            content: %{
              "model" => [
                %{
                  "type" => "content",
                  "children" => [
                    %{
                      "type" => "page_link",
                      "idref" => non_hierarchical_page3.resource_id,
                      "purpose" => "none",
                      "children" => [%{"text" => "Link to detached page"}]
                    }
                  ]
                }
              ]
            }
          }
        end),
        revision_tag: :scored_page2
      )
      |> Seeder.Project.edit_page(
        ref(:proj),
        ref(:non_hierarchical_page3),
        refs([:non_hierarchical_page5], fn [non_hierarchical_page5] ->
          %{
            content: %{
              "model" => [
                %{
                  "type" => "content",
                  "children" => [
                    %{
                      "type" => "page_link",
                      "idref" => non_hierarchical_page5.resource_id,
                      "purpose" => "none",
                      "children" => [%{"text" => "Link to detached page"}]
                    }
                  ]
                }
              ]
            }
          }
        end),
        revision_tag: :non_hierarchical_page3
      )
      |> Seeder.Project.ensure_published(ref(:pub))
      |> Seeder.Section.create_section(
        ref(:proj),
        ref(:pub),
        nil,
        %{},
        section_tag: :section
      )
    end

    test "returns a map with linked page resource ids", %{
      pub: pub,
      curriculum: curriculum,
      unit1: unit1,
      unscored_page1: unscored_page1,
      scored_page2: scored_page2,
      non_hierarchical_page3: non_hierarchical_page3,
      non_hierarchical_page5: non_hierarchical_page5
    } do
      page_link_map = Sections.build_resource_link_map([pub.id])

      assert page_link_map[unit1.resource_id] == [curriculum.resource_id]
      assert page_link_map[unscored_page1.resource_id] == [unit1.resource_id]
      assert page_link_map[scored_page2.resource_id] == [unit1.resource_id]
      assert page_link_map[non_hierarchical_page3.resource_id] == [scored_page2.resource_id]

      assert page_link_map[non_hierarchical_page5.resource_id] == [
               non_hierarchical_page3.resource_id
             ]
    end
  end

  describe "get_explorations_by_containers/1" do
    setup(_) do
      %{}
      |> Seeder.Project.create_author(author_tag: :author)
      |> Seeder.Project.create_sample_project(
        ref(:author),
        project_tag: :proj,
        publication_tag: :pub,
        curriculum_revision_tag: :curriculum,
        unit1_tag: :unit1,
        unscored_page1_tag: :unscored_page1,
        unscored_page1_activity_tag: :unscored_page1_activity,
        scored_page2_tag: :scored_page2,
        scored_page2_activity_tag: :scored_page2_activity
      )
      |> Seeder.Project.create_container(
        ref(:author),
        ref(:proj),
        ref(:unit1),
        %{
          title: "Nested Unit 1 Module 1"
        },
        revision_tag: :unit1_module1
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:proj),
        nil,
        %{
          title: "Exploration Page 3",
          purpose: :application
        },
        revision_tag: :exploration_page3
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:proj),
        nil,
        %{
          title: "Exploration Page 4",
          purpose: :application
        },
        revision_tag: :exploration_page4
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:proj),
        ref(:unit1_module1),
        refs([:exploration_page3], fn [exploration_page3] ->
          %{
            content: %{
              "model" => [
                %{
                  "type" => "content",
                  "children" => [
                    %{
                      "type" => "page_link",
                      "idref" => exploration_page3.resource_id,
                      "purpose" => "none",
                      "children" => [%{"text" => "Link to Exploration 3"}]
                    }
                  ]
                }
              ]
            }
          }
        end),
        revision_tag: :unit1_module1_page5
      )
      |> Seeder.Project.edit_page(
        ref(:proj),
        ref(:unscored_page1),
        refs([:exploration_page4], fn [exploration_page4] ->
          %{
            content: %{
              "model" => [
                %{
                  "type" => "content",
                  "children" => [
                    %{
                      "type" => "page_link",
                      "idref" => exploration_page4.resource_id,
                      "purpose" => "none",
                      "children" => [%{"text" => "Link to Exploration 4"}]
                    }
                  ]
                }
              ]
            }
          }
        end),
        revision_tag: :unscored_page1
      )
      |> Seeder.Project.ensure_published(ref(:pub))
      |> Seeder.Section.create_section(
        ref(:proj),
        ref(:pub),
        nil,
        %{},
        section_tag: :section
      )
    end

    @tag capture_log: true
    test "returns a map with container labels as keys and the explorations they link to", %{
      section: section,
      exploration_page3: exploration_page3,
      exploration_page4: exploration_page4
    } do
      explorations = Sections.get_explorations_by_containers(section, nil)

      exploration_page3_id = exploration_page3.id
      exploration_page4_id = exploration_page4.id

      assert [
               {"Unit 1: Unit 1",
                [{%Oli.Resources.Revision{id: ^exploration_page4_id}, :not_started}]},
               {"Module 1: Nested Unit 1 Module 1",
                [{%Oli.Resources.Revision{id: ^exploration_page3_id}, :not_started}]}
             ] = explorations
    end
  end

  describe "get_up_next/2" do
    setup do
      %{}
      |> Seeder.Project.create_author(author_tag: :author)
      |> Seeder.Project.create_sample_project(
        ref(:author),
        project_tag: :proj,
        publication_tag: :pub,
        curriculum_revision_tag: :curriculum,
        unit1_tag: :unit1,
        unscored_page1_tag: :unscored_page1,
        unscored_page1_activity_tag: :unscored_page1_activity,
        scored_page2_tag: :scored_page2,
        scored_page2_activity_tag: :scored_page2_activity
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:proj),
        nil,
        %{
          title: "Assessment 3",
          graded: true
        },
        resource_tag: :page3_resource,
        revision_tag: :page3
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:proj),
        nil,
        %{
          title: "Assessment 4",
          graded: true
        },
        resource_tag: :page4_resource,
        revision_tag: :page4
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:proj),
        nil,
        %{
          title: "Assessment 5",
          graded: true
        },
        resource_tag: :page5_resource,
        revision_tag: :page5
      )
      # attach pages to unit in a different order than creation
      |> Seeder.Project.attach_to(
        [ref(:page4_resource), ref(:page5_resource), ref(:page3_resource)],
        ref(:unit1),
        ref(:pub),
        container_revision_tag: :unit1
      )
      |> Seeder.Project.ensure_published(ref(:pub), publication_tag: :pub)
      |> Seeder.Section.create_section(
        ref(:proj),
        ref(:pub),
        nil,
        %{
          start_date: ~U[2023-01-27 23:59:59Z]
        },
        section_tag: :section
      )
      |> then(fn seeds ->
        section = seeds[:section]
        page3 = seeds[:page3]
        page4 = seeds[:page4]
        page5 = seeds[:page5]

        # create soft scheduling for pages
        scheduled_resources =
          Sections.Scheduling.retrieve(section)
          |> Enum.reduce(%{}, fn sr, acc -> Map.put(acc, sr.resource_id, sr) end)

        assert {:ok, 3} =
                 Sections.Scheduling.update(
                   section,
                   [
                     %{
                       id: scheduled_resources[page3.resource_id].id,
                       scheduling_type: "due_by",
                       start_date: "2023-02-03",
                       end_date: "2023-02-06",
                       manually_scheduled: true
                     },
                     %{
                       id: scheduled_resources[page4.resource_id].id,
                       scheduling_type: "due_by",
                       start_date: "2023-02-03",
                       end_date: "2023-02-06",
                       manually_scheduled: true
                     },
                     %{
                       id: scheduled_resources[page5.resource_id].id,
                       scheduling_type: "due_by",
                       start_date: "2023-02-05",
                       end_date: "2023-02-08",
                       manually_scheduled: true
                     }
                   ],
                   "Etc/UTC"
                 )

        seeds
      end)
      |> Seeder.Section.create_and_enroll_learner(
        ref(:section),
        %{},
        user_tag: :student1
      )
      |> Seeder.Section.create_and_enroll_instructor(
        ref(:section),
        %{},
        user_tag: :instructor1
      )
    end

    test "returns the content that is up next for a student", %{
      student1: student1,
      section: section,
      page3: page3,
      page4: page4,
      page5: page5
    } do
      page3_resource_id = page3.resource_id
      page4_resource_id = page4.resource_id
      page5_resource_id = page5.resource_id

      assert [
               {{~U[2023-02-03 23:59:59Z], ~U[2023-02-06 23:59:59Z]},
                [
                  %Oli.Delivery.Sections.SectionResource{
                    scheduling_type: :due_by,
                    manually_scheduled: true,
                    start_date: ~U[2023-02-03 23:59:59Z],
                    end_date: ~U[2023-02-06 23:59:59Z],
                    resource_id: ^page3_resource_id,
                    title: "Assessment 3"
                  },
                  %Oli.Delivery.Sections.SectionResource{
                    scheduling_type: :due_by,
                    manually_scheduled: true,
                    start_date: ~U[2023-02-03 23:59:59Z],
                    end_date: ~U[2023-02-06 23:59:59Z],
                    resource_id: ^page4_resource_id,
                    title: "Assessment 4"
                  }
                ]},
               {{~U[2023-02-05 23:59:59Z], ~U[2023-02-08 23:59:59Z]},
                [
                  %Oli.Delivery.Sections.SectionResource{
                    scheduling_type: :due_by,
                    manually_scheduled: true,
                    start_date: ~U[2023-02-05 23:59:59Z],
                    end_date: ~U[2023-02-08 23:59:59Z],
                    resource_id: ^page5_resource_id,
                    title: "Assessment 5"
                  }
                ]}
             ] = Sections.get_up_next(section, student1)
    end

    test "get_ordered_schedule", %{section: section} do
      IO.inspect(Sections.get_ordered_schedule(section), label: "get_ordered_schedule")
    end
  end

  describe "get_graded_pages/2" do
    setup do
      %{}
      |> Seeder.Project.create_author(author_tag: :author)
      |> Seeder.Project.create_sample_project(
        ref(:author),
        project_tag: :proj,
        publication_tag: :pub,
        curriculum_revision_tag: :curriculum,
        unit1_tag: :unit1,
        unscored_page1_tag: :unscored_page1,
        unscored_page1_activity_tag: :unscored_page1_activity,
        scored_page2_tag: :scored_page2,
        scored_page2_activity_tag: :scored_page2_activity
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:proj),
        nil,
        %{
          title: "Assessment 3",
          graded: true
        },
        resource_tag: :page3_resource,
        revision_tag: :page3
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:proj),
        nil,
        %{
          title: "Assessment 4",
          graded: true
        },
        resource_tag: :page4_resource,
        revision_tag: :page4
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:proj),
        nil,
        %{
          title: "Assessment 5",
          graded: true
        },
        resource_tag: :page5_resource,
        revision_tag: :page5
      )
      # attach pages to unit in a different order than creation
      |> Seeder.Project.attach_to(
        [ref(:page4_resource), ref(:page5_resource), ref(:page3_resource)],
        ref(:unit1),
        ref(:pub),
        container_revision_tag: :unit1
      )
      |> Seeder.Project.ensure_published(ref(:pub), publication_tag: :pub)
      |> Seeder.Section.create_section(
        ref(:proj),
        ref(:pub),
        nil,
        %{},
        section_tag: :section
      )
      |> Seeder.Section.create_and_enroll_learner(
        ref(:section),
        %{},
        user_tag: :student1
      )
      |> Seeder.Section.create_and_enroll_instructor(
        ref(:section),
        %{},
        user_tag: :instructor1
      )
    end

    test "properly sorts assignments first by schedule and second hierarchy", %{
      student1: student1,
      section: section,
      page3: page3,
      page4: page4,
      page5: page5,
      scored_page2: scored_page2
    } do
      scheduled_resources =
        Sections.Scheduling.retrieve(section)
        |> Enum.reduce(%{}, fn sr, acc -> Map.put(acc, sr.resource_id, sr) end)

      # update assignments to have same scheduled date and different start_date
      assert {:ok, 3} =
               Sections.Scheduling.update(
                 section,
                 [
                   %{
                     id: scheduled_resources[page3.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-03",
                     end_date: "2023-02-06",
                     manually_scheduled: true
                   },
                   %{
                     id: scheduled_resources[page4.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-04",
                     end_date: "2023-02-06",
                     manually_scheduled: true
                   },
                   %{
                     id: scheduled_resources[page5.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-05",
                     end_date: "2023-02-06",
                     manually_scheduled: true
                   }
                 ],
                 "Etc/UTC"
               )

      page4_resource_id = page4.resource_id
      page5_resource_id = page5.resource_id
      page3_resource_id = page3.resource_id
      scored_page2_resource_id = scored_page2.resource_id

      page_4_numbering_index =
        Sections.get_section_resource(section.id, page4.resource_id).numbering_index

      page_5_numbering_index =
        Sections.get_section_resource(section.id, page5.resource_id).numbering_index

      page_3_numbering_index =
        Sections.get_section_resource(section.id, page3.resource_id).numbering_index

      scored_page_2_numbering_index =
        Sections.get_section_resource(section.id, scored_page2.resource_id).numbering_index

      # verify that the assignments are sorted by schedule and then by hierarchy
      # assignments without a scheduled date are listed after and are just sorted by hierarchy
      # to sort the resources does not matter the start_date
      # as the resources has the same scheduled date, so the order is by hierarchy
      assert [
               %{resource_id: ^page4_resource_id, numbering_index: ^page_4_numbering_index},
               %{resource_id: ^page5_resource_id, numbering_index: ^page_5_numbering_index},
               %{resource_id: ^page3_resource_id, numbering_index: ^page_3_numbering_index},
               %{
                 resource_id: ^scored_page2_resource_id,
                 numbering_index: ^scored_page_2_numbering_index
               }
             ] =
               Sections.get_graded_pages(section.slug, student1.id)
    end

    test "properly sorts assignments without a scheduled date by hierarchy", %{
      student1: student1,
      section: section,
      page3: page3,
      page4: page4,
      page5: page5,
      scored_page2: scored_page2
    } do
      page4_resource_id = page4.resource_id
      page5_resource_id = page5.resource_id
      page3_resource_id = page3.resource_id
      scored_page2_resource_id = scored_page2.resource_id

      page_4_numbering_index =
        Sections.get_section_resource(section.id, page4.resource_id).numbering_index

      page_5_numbering_index =
        Sections.get_section_resource(section.id, page5.resource_id).numbering_index

      page_3_numbering_index =
        Sections.get_section_resource(section.id, page3.resource_id).numbering_index

      scored_page_2_numbering_index =
        Sections.get_section_resource(section.id, scored_page2.resource_id).numbering_index

      # verify that the assignments are sorted by hierarchy because they do not have a scheduled date
      # scored_page_2_numbering_index: 2
      # page_4_numbering_index: 3
      # page_5_numbering_index: 4
      # page_3_numbering_index: 5

      assert [
               %{
                 resource_id: ^scored_page2_resource_id,
                 numbering_index: ^scored_page_2_numbering_index
               },
               %{resource_id: ^page4_resource_id, numbering_index: ^page_4_numbering_index},
               %{resource_id: ^page5_resource_id, numbering_index: ^page_5_numbering_index},
               %{resource_id: ^page3_resource_id, numbering_index: ^page_3_numbering_index}
             ] =
               Sections.get_graded_pages(section.slug, student1.id)
    end

    test "properly sorts assignments with different scheduled date by scheduled date", %{
      student1: student1,
      section: section,
      page3: page3,
      page4: page4,
      page5: page5,
      scored_page2: scored_page2
    } do
      scheduled_resources =
        Sections.Scheduling.retrieve(section)
        |> Enum.reduce(%{}, fn sr, acc -> Map.put(acc, sr.resource_id, sr) end)

      # update assignments to have differents scheduled date (end_date)
      assert {:ok, 4} =
               Sections.Scheduling.update(
                 section,
                 [
                   %{
                     id: scheduled_resources[page3.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-04",
                     end_date: "2023-02-06",
                     manually_scheduled: true
                   },
                   %{
                     id: scheduled_resources[page4.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-05",
                     end_date: "2023-02-07",
                     manually_scheduled: true
                   },
                   %{
                     id: scheduled_resources[page5.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-03",
                     end_date: "2023-02-08",
                     manually_scheduled: true
                   },
                   %{
                     id: scheduled_resources[scored_page2.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-02",
                     end_date: "2023-02-09",
                     manually_scheduled: true
                   }
                 ],
                 "Etc/UTC"
               )

      page4_resource_id = page4.resource_id
      page5_resource_id = page5.resource_id
      page3_resource_id = page3.resource_id
      scored_page2_resource_id = scored_page2.resource_id

      # verify that the assignments have different scheduled date then are sorted by scheduled date (end_date)

      assert [
               %{resource_id: ^page3_resource_id},
               %{resource_id: ^page4_resource_id},
               %{resource_id: ^page5_resource_id},
               %{
                 resource_id: ^scored_page2_resource_id
               }
             ] =
               Sections.get_graded_pages(section.slug, student1.id)
    end

    test "properly sorts assignments that have due_by and read_by scheduling_type", %{
      student1: student1,
      section: section,
      page3: page3,
      page4: page4,
      page5: page5,
      scored_page2: scored_page2
    } do
      scheduled_resources =
        Sections.Scheduling.retrieve(section)
        |> Enum.reduce(%{}, fn sr, acc -> Map.put(acc, sr.resource_id, sr) end)

      # update assignments to have differents scheduled date, and set numbering_level and numbering_index
      assert {:ok, 4} =
               Sections.Scheduling.update(
                 section,
                 [
                   %{
                     id: scheduled_resources[page3.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-04",
                     end_date: "2023-02-06",
                     manually_scheduled: true
                   },
                   %{
                     id: scheduled_resources[page4.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-05",
                     end_date: "2023-02-07",
                     manually_scheduled: true
                   },
                   %{
                     id: scheduled_resources[page5.resource_id].id,
                     scheduling_type: "read_by",
                     start_date: "2023-02-03",
                     end_date: nil,
                     manually_scheduled: true
                   },
                   %{
                     id: scheduled_resources[scored_page2.resource_id].id,
                     scheduling_type: "read_by",
                     start_date: "2023-02-02",
                     end_date: nil,
                     manually_scheduled: true
                   }
                 ],
                 "Etc/UTC"
               )

      page4_resource_id = page4.resource_id
      page5_resource_id = page5.resource_id
      page3_resource_id = page3.resource_id
      scored_page2_resource_id = scored_page2.resource_id

      # verify that the assignments are sorted by scheduled date (end_date) and then by hierarchy
      # first are ordered the assignments with scheduling_type = "due_by" depending this date, and then are ordered the assignments by hierarchy (numbering_index)

      assert [
               %{resource_id: ^page3_resource_id},
               %{resource_id: ^page4_resource_id},
               %{
                 resource_id: ^scored_page2_resource_id
               },
               %{resource_id: ^page5_resource_id}
             ] =
               Sections.get_graded_pages(section.slug, student1.id)
    end
  end
end
