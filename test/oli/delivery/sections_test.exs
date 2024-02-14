defmodule Oli.Delivery.SectionsTest do
  use OliWeb.ConnCase

  import Oli.Utils.Seeder.Utils
  import Oli.Factory

  alias Oli.Utils.Seeder
  alias Oli.Factory
  alias Oli.Delivery.Sections

  alias Oli.Delivery.Sections.{
    PostProcessing,
    SectionResource,
    ScheduledContainerGroup,
    ScheduledSectionResource
  }

  alias Oli.Publishing.DeliveryResolver

  describe "PostProcessing.apply/2 case :discussions" do
    alias Oli.Resources.ResourceType
    alias Oli.Resources.Collaboration.CollabSpaceConfig
    import Oli.Factory
    import Oli.TestHelpers
    @page_type_id ResourceType.id_for_page()
    @container_type_id ResourceType.id_for_container()

    test "sets contains_discussions to true when having active discussions" do
      # Project and Author
      %{authors: [author]} = project = create_project_with_assocs()

      # Root container
      %{resource: container_resource, revision: container_revision, publication: publication} =
        create_bundle_for(@container_type_id, project, author, nil, nil, title: "Root container")

      # Resources
      pages =
        for _x <- 1..3, do: create_bundle_for(@page_type_id, project, author, publication)

      others =
        for _x <- 1..2, do: create_bundle_for(@container_type_id, project, author, publication)

      pages_resources = Enum.map(pages, & &1.resource)
      others_resources = Enum.map(others, & &1.resource)
      # Links container - page
      assoc_resources(
        pages_resources ++ others_resources,
        container_revision,
        container_resource,
        publication
      )

      # Section and its section_resources
      {:ok, section} =
        insert(:section, base_project: project, open_and_free: true)
        |> Sections.create_section_resources(publication)

      refute section.contains_discussions

      all_section_resources =
        section |> Oli.Repo.preload(:section_resources) |> Map.get(:section_resources)

      {pages_section_resources, _rest_section_resources} =
        Enum.split_with(all_section_resources, fn sr ->
          sr.resource_id in Enum.map(pages_resources, & &1.id)
        end)

      [id_sec_res_1, id_sec_res_2, id_sec_res_3] = Enum.map(pages_section_resources, & &1.id)

      enabled_collab_space_config = set_collab_space_config_status(:enabled)
      disabled_collab_space_config = set_collab_space_config_status(:disabled)
      archived_collab_space_config = set_collab_space_config_status(:archived)

      add_collab_space_config_to_section_resource(id_sec_res_1, enabled_collab_space_config)
      add_collab_space_config_to_section_resource(id_sec_res_2, disabled_collab_space_config)
      add_collab_space_config_to_section_resource(id_sec_res_3, archived_collab_space_config)

      PostProcessing.apply(section, :discussions)

      assert Oli.Repo.reload!(section).contains_discussions
    end

    test "sets contains_discussions to false when NO having active discussions" do
      # Project and Author
      %{authors: [author]} = project = create_project_with_assocs()

      # Root container
      %{resource: container_resource, revision: container_revision, publication: publication} =
        create_bundle_for(@container_type_id, project, author, nil, nil, title: "Root container")

      # Resources
      pages =
        for _x <- 1..3, do: create_bundle_for(@page_type_id, project, author, publication)

      others =
        for _x <- 1..2, do: create_bundle_for(@container_type_id, project, author, publication)

      pages_resources = Enum.map(pages, & &1.resource)
      others_resources = Enum.map(others, & &1.resource)
      # Links container - page
      assoc_resources(
        pages_resources ++ others_resources,
        container_revision,
        container_resource,
        publication
      )

      # Section and its section_resources
      {:ok, section} =
        insert(:section, base_project: project, open_and_free: true)
        |> Sections.create_section_resources(publication)

      refute section.contains_discussions

      all_section_resources =
        section |> Oli.Repo.preload(:section_resources) |> Map.get(:section_resources)

      {pages_section_resources, _rest_section_resources} =
        Enum.split_with(all_section_resources, fn sr ->
          sr.resource_id in Enum.map(pages_resources, & &1.id)
        end)

      [id_sec_res_1, id_sec_res_2, id_sec_res_3] = Enum.map(pages_section_resources, & &1.id)

      disabled_collab_space_config = set_collab_space_config_status(:disabled)
      archived_collab_space_config = set_collab_space_config_status(:archived)

      add_collab_space_config_to_section_resource(id_sec_res_1, disabled_collab_space_config)
      add_collab_space_config_to_section_resource(id_sec_res_2, disabled_collab_space_config)
      add_collab_space_config_to_section_resource(id_sec_res_3, archived_collab_space_config)

      PostProcessing.apply(section, :discussions)

      refute Oli.Repo.reload!(section).contains_discussions
    end

    defp set_collab_space_config_status(status) do
      %CollabSpaceConfig{}
      |> CollabSpaceConfig.changeset(%{status: status})
      |> Ecto.Changeset.apply_changes()
    end

    defp add_collab_space_config_to_section_resource(section_resource_id, collab_space_config) do
      SectionResource
      |> Oli.Repo.get!(section_resource_id)
      |> SectionResource.changeset()
      |> Ecto.Changeset.put_embed(:collab_space_config, collab_space_config)
      |> Oli.Repo.update!()
    end
  end

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

    @tag capture_log: true
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
      |> Seeder.Project.create_large_sample_project(ref(:author))
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:project),
        nil,
        %{
          title: "Non-Hierarchical Page 15",
          graded: false
        },
        revision_tag: :non_hierarchical_page15
      )
      |> Seeder.Project.create_page(
        ref(:author),
        ref(:project),
        nil,
        %{
          title: "Non-Hierarchical Exploration Page 16",
          purpose: :application
        },
        revision_tag: :non_hierarchical_page16
      )
      |> Seeder.Project.edit_page(
        ref(:project),
        ref(:unit1_module1_page2),
        refs([:non_hierarchical_page15], fn [non_hierarchical_page15] ->
          %{
            content: %{
              "model" => [
                %{
                  "type" => "content",
                  "children" => [
                    %{
                      "type" => "page_link",
                      "idref" => non_hierarchical_page15.resource_id,
                      "purpose" => "none",
                      "children" => [%{"text" => "Link to detached page"}]
                    }
                  ]
                }
              ]
            }
          }
        end),
        revision_tag: :unit1_module1_page2
      )
      |> Seeder.Project.edit_page(
        ref(:project),
        ref(:unit1_module1_section1_page5),
        refs([:non_hierarchical_page16], fn [non_hierarchical_page16] ->
          %{
            content: %{
              "model" => [
                %{
                  "type" => "content",
                  "children" => [
                    %{
                      "type" => "page_link",
                      "idref" => non_hierarchical_page16.resource_id,
                      "purpose" => "none",
                      "children" => [%{"text" => "Link to detached page"}]
                    }
                  ]
                }
              ]
            }
          }
        end),
        revision_tag: :unit1_module1_section1_page5
      )
      |> Seeder.Project.ensure_published(ref(:publication))
      |> Seeder.Section.create_section(
        ref(:project),
        ref(:publication),
        nil,
        %{},
        section_tag: :section
      )
    end

    test "returns a map with linked page resource ids", %{
      publication: publication,
      curriculum: curriculum,
      unit1: unit1,
      unit1_page1: unit1_page1,
      unit1_module1: unit1_module1,
      unit1_module1_page2: unit1_module1_page2,
      unit1_module1_section1: unit1_module1_section1,
      unit1_module1_section_1_page4: unit1_module1_section_1_page4,
      unit1_module1_section1_page5: unit1_module1_section1_page5,
      unit1_module1_exploration_page6: unit1_module1_exploration_page6,
      unit1_module1_scored_page7: unit1_module1_scored_page7,
      unit1_module2: unit1_module2,
      unit1_module2_page8: unit1_module2_page8,
      unit1_exploration_page9: unit1_exploration_page9,
      unit1_scored_page10: unit1_scored_page10,
      unit2: unit2,
      unit2_page11: unit2_page11,
      unit2_module3: unit2_module3,
      unit2_module3_page12: unit2_module3_page12,
      unit2_exploration_page13: unit2_exploration_page13,
      unit2_scored_page14: unit2_scored_page14,
      non_hierarchical_page15: non_hierarchical_page15,
      non_hierarchical_page16: non_hierarchical_page16
    } do
      page_link_map = Sections.build_resource_link_map([publication.id])

      assert page_link_map[unit1.resource_id] == [curriculum.resource_id]
      assert page_link_map[unit1_page1.resource_id] == [unit1.resource_id]
      assert page_link_map[unit1_module1.resource_id] == [unit1.resource_id]
      assert page_link_map[unit1_module1_page2.resource_id] == [unit1_module1.resource_id]
      assert page_link_map[unit1_module1_section1.resource_id] == [unit1_module1.resource_id]

      assert page_link_map[unit1_module1_section_1_page4.resource_id] == [
               unit1_module1_section1.resource_id
             ]

      assert page_link_map[unit1_module1_section1_page5.resource_id] == [
               unit1_module1_section1.resource_id
             ]

      assert page_link_map[unit1_module1_exploration_page6.resource_id] == [
               unit1_module1.resource_id
             ]

      assert page_link_map[unit1_module1_scored_page7.resource_id] == [
               unit1_module1.resource_id
             ]

      assert page_link_map[unit1_module2.resource_id] == [
               unit1.resource_id
             ]

      assert page_link_map[unit1_module2_page8.resource_id] == [
               unit1_module2.resource_id
             ]

      assert page_link_map[unit1_exploration_page9.resource_id] == [unit1.resource_id]
      assert page_link_map[unit1_scored_page10.resource_id] == [unit1.resource_id]
      assert page_link_map[unit2.resource_id] == [curriculum.resource_id]
      assert page_link_map[unit2_page11.resource_id] == [unit2.resource_id]
      assert page_link_map[unit2_module3.resource_id] == [unit2.resource_id]
      assert page_link_map[unit2_module3_page12.resource_id] == [unit2_module3.resource_id]
      assert page_link_map[unit2_exploration_page13.resource_id] == [unit2.resource_id]
      assert page_link_map[unit2_scored_page14.resource_id] == [unit2.resource_id]

      assert page_link_map[non_hierarchical_page15.resource_id] == [
               unit1_module1_page2.resource_id
             ]

      assert page_link_map[non_hierarchical_page15.resource_id] == [
               unit1_module1_page2.resource_id
             ]

      assert page_link_map[non_hierarchical_page16.resource_id] == [
               unit1_module1_section1_page5.resource_id
             ]
    end

    test "find_parent_container/4", %{
      section: section,
      publication: publication,
      unit1: unit1,
      unit1_page1: unit1_page1,
      unit1_module1: unit1_module1,
      unit1_exploration_page9: unit1_exploration_page9,
      non_hierarchical_page15: non_hierarchical_page15
    } do
      page_link_map = Sections.build_resource_link_map([publication.id])

      all_containers =
        DeliveryResolver.revisions_of_type(
          section.slug,
          Oli.Resources.ResourceType.get_id_by_type("container")
        )

      container_ids = Enum.map(all_containers, fn c -> c.resource_id end)

      {parent_resource_id, _} =
        Sections.find_parent_container(
          unit1_exploration_page9.resource_id,
          page_link_map,
          MapSet.new(container_ids),
          MapSet.new()
        )

      assert parent_resource_id == unit1.resource_id

      {parent_resource_id, _} =
        Sections.find_parent_container(
          non_hierarchical_page15.resource_id,
          page_link_map,
          MapSet.new(container_ids),
          MapSet.new()
        )

      assert parent_resource_id == unit1_module1.resource_id

      {parent_resource_id, _} =
        Sections.find_parent_container(
          unit1_page1.resource_id,
          page_link_map,
          MapSet.new(container_ids),
          MapSet.new()
        )

      assert parent_resource_id == unit1.resource_id
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
        %{slug: "section_#{UUID.uuid4()}"},
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

  describe "get_ordered_container_labels/1" do
    setup(_) do
      %{}
      |> Seeder.Project.create_author(author_tag: :author)
      |> Seeder.Project.create_large_sample_project(ref(:author))
      |> Seeder.Project.ensure_published(ref(:publication))
      |> Seeder.Section.create_section(
        ref(:project),
        ref(:publication),
        nil,
        %{},
        section_tag: :section
      )
    end

    test "returns the correct ordered container labels for a section", %{
      section: section,
      unit1: unit1,
      unit1_module1: unit1_module1,
      unit1_module1_section1: unit1_module1_section1,
      unit1_module2: unit1_module2,
      unit2: unit2,
      unit2_module3: unit2_module3
    } do
      ordered_labels = Sections.fetch_ordered_container_labels(section.slug)

      assert Enum.count(ordered_labels) == 6

      assert Enum.at(ordered_labels, 0) == {unit1.resource_id, "Unit 1: Unit 1"}

      assert Enum.at(ordered_labels, 1) ==
               {unit1_module1.resource_id, "Module 1: Unit 1 Module 1"}

      assert Enum.at(ordered_labels, 2) ==
               {unit1_module1_section1.resource_id, "Section 1: Unit 1 Module 1 Section 1"}

      assert Enum.at(ordered_labels, 3) ==
               {unit1_module2.resource_id, "Module 2: Unit 1 Module 2"}

      assert Enum.at(ordered_labels, 4) == {unit2.resource_id, "Unit 2: Unit 2"}

      assert Enum.at(ordered_labels, 5) ==
               {unit2_module3.resource_id, "Module 3: Unit 2 Module 3"}
    end
  end

  describe "get_ordered_schedule/1" do
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
          slug: "section_#{UUID.uuid4()}",
          start_date: ~U[2023-01-24 23:59:59Z]
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
                       start_date: "2023-01-25",
                       end_date: "2023-01-27",
                       manually_scheduled: true
                     },
                     %{
                       id: scheduled_resources[page4.resource_id].id,
                       scheduling_type: "due_by",
                       start_date: "2023-02-01",
                       end_date: "2023-02-04",
                       manually_scheduled: true
                     },
                     %{
                       id: scheduled_resources[page5.resource_id].id,
                       scheduling_type: "due_by",
                       start_date: "2023-02-06",
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

    @tag capture_log: true
    test "get_ordered_schedule", %{
      section: section,
      student1: student1,
      unit1: unit1,
      page3: page3,
      page4: page4,
      page5: page5
    } do
      unit1_resource_id = unit1.resource_id
      page3_resource_id = page3.resource_id
      page4_resource_id = page4.resource_id
      page5_resource_id = page5.resource_id

      assert [
               {
                 {1, 2023},
                 [
                   {1,
                    [
                      {{~U[2023-01-25 23:59:59Z], ~U[2023-01-27 23:59:59Z]},
                       [
                         %ScheduledContainerGroup{
                           container_id: ^unit1_resource_id,
                           container_label: "Unit 1",
                           graded: true,
                           progress: nil,
                           resources: [
                             %ScheduledSectionResource{
                               resource: %Oli.Delivery.Sections.SectionResource{
                                 scheduling_type: :due_by,
                                 manually_scheduled: true,
                                 start_date: ~U[2023-01-25 23:59:59Z],
                                 end_date: ~U[2023-01-27 23:59:59Z],
                                 resource_id: ^page3_resource_id,
                                 title: "Assessment 3"
                               },
                               purpose: :foundation,
                               progress: nil,
                               raw_avg_score: nil,
                               resource_attempt_count: 0,
                               effective_settings: %Oli.Delivery.Settings.Combined{
                                 resource_id: ^page3_resource_id
                               }
                             }
                           ]
                         }
                       ]}
                    ]}
                 ]
               },
               {{2, 2023},
                [
                  {2,
                   [
                     {{~U[2023-02-01 23:59:59Z], ~U[2023-02-04 23:59:59Z]},
                      [
                        %ScheduledContainerGroup{
                          container_id: ^unit1_resource_id,
                          container_label: "Unit 1",
                          graded: true,
                          progress: nil,
                          resources: [
                            %ScheduledSectionResource{
                              resource: %Oli.Delivery.Sections.SectionResource{
                                scheduling_type: :due_by,
                                manually_scheduled: true,
                                start_date: ~U[2023-02-01 23:59:59Z],
                                end_date: ~U[2023-02-04 23:59:59Z],
                                resource_id: ^page4_resource_id,
                                title: "Assessment 4"
                              },
                              purpose: :foundation,
                              progress: nil,
                              raw_avg_score: nil,
                              resource_attempt_count: 0,
                              effective_settings: %Oli.Delivery.Settings.Combined{
                                resource_id: ^page4_resource_id
                              }
                            }
                          ]
                        }
                      ]}
                   ]},
                  {3,
                   [
                     {{~U[2023-02-06 23:59:59Z], ~U[2023-02-08 23:59:59Z]},
                      [
                        %ScheduledContainerGroup{
                          container_id: ^unit1_resource_id,
                          container_label: "Unit 1",
                          graded: true,
                          progress: nil,
                          resources: [
                            %ScheduledSectionResource{
                              resource: %Oli.Delivery.Sections.SectionResource{
                                scheduling_type: :due_by,
                                manually_scheduled: true,
                                start_date: ~U[2023-02-06 23:59:59Z],
                                end_date: ~U[2023-02-08 23:59:59Z],
                                resource_id: ^page5_resource_id,
                                title: "Assessment 5"
                              },
                              purpose: :foundation,
                              progress: nil,
                              raw_avg_score: nil,
                              resource_attempt_count: 0,
                              effective_settings: %Oli.Delivery.Settings.Combined{
                                resource_id: ^page5_resource_id
                              }
                            }
                          ]
                        }
                      ]}
                   ]}
                ]}
             ] =
               Sections.get_ordered_schedule(section, student1.id)
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

  describe "get_container_label_and_numbering/2" do
    setup _ do
      author = insert(:author)
      project = insert(:project, authors: [author])

      # revisions...
      ## section container...
      section_1_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container")
        })

      section_2_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container")
        })

      ## module...
      module_1_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
          children: [section_1_revision.resource_id, section_2_revision.resource_id]
        })

      module_2_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container")
        })

      ## unit...
      unit_1_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
          children: [module_1_revision.resource_id, module_2_revision.resource_id]
        })

      unit_2_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container")
        })

      ## root container...
      container_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
          children: [unit_1_revision.resource_id, unit_2_revision.resource_id],
          title: "Root Container"
        })

      all_revisions =
        [
          section_1_revision,
          section_2_revision,
          module_1_revision,
          module_2_revision,
          unit_1_revision,
          unit_2_revision,
          container_revision
        ]

      # asociate resources to project
      Enum.each(all_revisions, fn revision ->
        insert(:project_resource, %{
          project_id: project.id,
          resource_id: revision.resource_id
        })
      end)

      # publish project
      publication =
        insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

      # publish resources
      Enum.each(all_revisions, fn revision ->
        insert(:published_resource, %{
          publication: publication,
          resource: revision.resource,
          revision: revision,
          author: author
        })
      end)

      # create section...
      section =
        insert(:section,
          base_project: project,
          analytics_version: :v2
        )

      {:ok, section} = Sections.create_section_resources(section, publication)
      {:ok, _} = Sections.rebuild_contained_pages(section)
      {:ok, _} = Sections.rebuild_contained_objectives(section)

      %{
        section: section,
        project: project,
        publication: publication,
        section_1: section_1_revision,
        section_2: section_2_revision,
        module_1: module_1_revision,
        module_2: module_2_revision,
        unit_1: unit_1_revision,
        unit_2: unit_2_revision
      }
    end

    test "returns the correct label for a section without custom labels", %{
      section: section,
      section_1: section_1,
      section_2: section_2,
      module_1: module_1,
      module_2: module_2,
      unit_1: unit_1,
      unit_2: unit_2
    } do
      section_1_section_resource =
        Sections.get_section_resource(section.id, section_1.resource_id)

      section_2_section_resource =
        Sections.get_section_resource(section.id, section_2.resource_id)

      module_1_section_resource =
        Sections.get_section_resource(section.id, module_1.resource_id)

      module_2_section_resource =
        Sections.get_section_resource(section.id, module_2.resource_id)

      unit_1_section_resource =
        Sections.get_section_resource(section.id, unit_1.resource_id)

      unit_2_section_resource =
        Sections.get_section_resource(section.id, unit_2.resource_id)

      assert Sections.get_container_label_and_numbering(
               section_1_section_resource,
               section.customizations
             ) == "Section 1"

      assert Sections.get_container_label_and_numbering(
               section_2_section_resource,
               section.customizations
             ) == "Section 2"

      assert Sections.get_container_label_and_numbering(
               module_1_section_resource,
               section.customizations
             ) == "Module 1"

      assert Sections.get_container_label_and_numbering(
               module_2_section_resource,
               section.customizations
             ) == "Module 2"

      assert Sections.get_container_label_and_numbering(
               unit_1_section_resource,
               section.customizations
             ) == "Unit 1"

      assert Sections.get_container_label_and_numbering(
               unit_2_section_resource,
               section.customizations
             ) == "Unit 2"
    end

    test "returns the correct label for a section with custom labels", %{
      section: section,
      section_1: section_1,
      section_2: section_2,
      module_1: module_1,
      module_2: module_2,
      unit_1: unit_1,
      unit_2: unit_2
    } do
      section_1_section_resource =
        Sections.get_section_resource(section.id, section_1.resource_id)

      section_2_section_resource =
        Sections.get_section_resource(section.id, section_2.resource_id)

      module_1_section_resource =
        Sections.get_section_resource(section.id, module_1.resource_id)

      module_2_section_resource =
        Sections.get_section_resource(section.id, module_2.resource_id)

      unit_1_section_resource =
        Sections.get_section_resource(section.id, unit_1.resource_id)

      unit_2_section_resource =
        Sections.get_section_resource(section.id, unit_2.resource_id)

      custom_labels = %{unit: "Volume", module: "Chapter", section: "Lesson"}

      assert Sections.get_container_label_and_numbering(
               section_1_section_resource,
               custom_labels
             ) == "Lesson 1"

      assert Sections.get_container_label_and_numbering(
               section_2_section_resource,
               custom_labels
             ) == "Lesson 2"

      assert Sections.get_container_label_and_numbering(
               module_1_section_resource,
               custom_labels
             ) == "Chapter 1"

      assert Sections.get_container_label_and_numbering(
               module_2_section_resource,
               custom_labels
             ) == "Chapter 2"

      assert Sections.get_container_label_and_numbering(
               unit_1_section_resource,
               custom_labels
             ) == "Volume 1"

      assert Sections.get_container_label_and_numbering(
               unit_2_section_resource,
               custom_labels
             ) == "Volume 2"
    end
  end
end
