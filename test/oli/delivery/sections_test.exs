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

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ResourceAccess

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.ResourceType
  alias Lti_1p3.Roles.ContextRoles

  defp set_progress(
         section_id,
         resource_id,
         user_id,
         progress,
         revision,
         opts \\ [attempt_state: :evaluated]
       ) do
    {:ok, resource_access} =
      Core.track_access(resource_id, section_id, user_id)
      |> Core.update_resource_access(%{progress: progress, score: 5.0, out_of: 10.0})

    attempt_attrs =
      case opts[:updated_at] do
        nil ->
          %{}

        updated_at ->
          Ecto.Changeset.change(resource_access, updated_at: updated_at)
          |> Oli.Repo.update()

          %{updated_at: updated_at}
      end

    insert(
      :resource_attempt,
      Map.merge(attempt_attrs, %{
        resource_access: resource_access,
        revision: revision,
        lifecycle_state: opts[:attempt_state],
        date_submitted:
          if(opts[:attempt_state] == :evaluated, do: ~U[2024-05-16 20:00:00Z], else: nil)
      })
    )

    insert(:resource_summary, %{
      resource_id: resource_id,
      section_id: section_id,
      user_id: user_id
    })
  end

  defp initiate_resource_attempt(
         page,
         student,
         section,
         attempt_updated_at \\ nil
       ) do
    resource_access =
      case Oli.Repo.get_by(
             ResourceAccess,
             resource_id: page.resource_id,
             section_id: section.id,
             user_id: student.id
           ) do
        nil ->
          insert(:resource_access, %{
            resource: page.resource,
            section: section,
            user: student
          })

        ra ->
          ra
      end

    attempt_attrs =
      case attempt_updated_at do
        nil -> %{}
        updated_at -> %{updated_at: updated_at}
      end

    insert(
      :resource_attempt,
      Map.merge(attempt_attrs, %{
        resource_access: resource_access,
        revision: page,
        lifecycle_state: :active,
        score: 0,
        out_of: 1
      })
    )
  end

  defp create_maths_project(_) do
    author = insert(:author)
    maths_project = insert(:project, authors: [author])

    # revisions...

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 1",
        duration_minutes: 10
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id],
        title: "How to use this course"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id],
        title: "Introduction"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [unit_1_revision.resource_id],
        title: "Root Container"
      })

    all_revisions = [page_1_revision, module_1_revision, unit_1_revision, container_revision]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: maths_project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{
        project: maths_project,
        root_resource_id: container_revision.resource_id
      })

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
        base_project: maths_project,
        title: "Maths Course",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)
    {:ok, _} = Sections.rebuild_contained_objectives(section)

    %{
      maths_author: author,
      maths_section: section,
      maths_project: maths_project,
      maths_publication: publication,
      maths_page_1: page_1_revision,
      maths_module_1: module_1_revision,
      maths_unit_1: unit_1_revision,
      maths_container_revision: container_revision
    }
  end

  defp create_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 1",
        duration_minutes: 10
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 2",
        duration_minutes: 15
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 3",
        graded: true,
        purpose: :application
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 4",
        graded: true
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        title: "How to use this course"
      })

    module_2_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [page_3_revision.resource_id],
        title: "Configure your setup"
      })

    deleted_module_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [],
        title: "Deleted Module",
        deleted: true
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [
          module_1_revision.resource_id,
          module_2_revision.resource_id,
          deleted_module_revision.resource_id
        ],
        title: "Introduction"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("container"),
        intro_content: %{
          "children" => [
            %{
              "children" => [%{"text" => "Welcome to the best course ever!"}],
              "id" => "3477687079",
              "type" => "p"
            }
          ],
          "type" => "p"
        },
        children: [
          unit_1_revision.resource_id,
          page_4_revision.resource_id
        ],
        title: "Root Container"
      })

    all_revisions =
      [
        page_1_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        module_1_revision,
        module_2_revision,
        deleted_module_revision,
        unit_1_revision,
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
        title: "The best course ever!",
        start_date: ~U[2023-10-30 20:00:00Z],
        analytics_version: :v2
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)
    {:ok, _} = Sections.rebuild_contained_objectives(section)

    # schedule start and end date for unit 1 section_resource
    Sections.get_section_resource(section.id, unit_1_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-10-31 20:00:00Z],
      end_date: ~U[2023-12-31 20:00:00Z]
    })

    # schedule start and end date for module 1 section_resource
    Sections.get_section_resource(section.id, module_1_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-01 20:00:00Z],
      end_date: ~U[2023-11-15 20:00:00Z]
    })

    # schedule start and end date for page 1 to 3 section_resource
    Sections.get_section_resource(section.id, page_1_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-01 20:00:00Z],
      end_date: ~U[2023-11-02 20:00:00Z]
    })

    Sections.get_section_resource(section.id, page_2_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-02 20:00:00Z],
      end_date: ~U[2023-11-03 20:00:00Z]
    })

    Sections.get_section_resource(section.id, page_3_revision.resource_id)
    |> Sections.update_section_resource(%{
      start_date: ~U[2023-11-03 20:00:00Z],
      end_date: ~U[2023-11-04 20:00:00Z]
    })

    %{
      author: author,
      section: section,
      project: project,
      publication: publication,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      deleted_module: deleted_module_revision,
      unit_1: unit_1_revision,
      container_revision: container_revision
    }
  end

  describe "PostProcessing.apply/2 case :discussions" do
    alias ResourceType
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
      stub_current_time(~U[2023-11-04 20:00:00Z])

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
          ResourceType.get_id_by_type("container")
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
      curriculum: curriculum,
      unit1: unit1,
      unit1_module1: unit1_module1,
      unit1_module1_section1: unit1_module1_section1,
      unit1_module2: unit1_module2,
      unit2: unit2,
      unit2_module3: unit2_module3
    } do
      ordered_labels = Sections.fetch_ordered_container_labels(section.slug)

      assert Enum.count(ordered_labels) == 7

      assert Enum.at(ordered_labels, 0) == {curriculum.resource_id, "Curriculum 1: Curriculum"}

      assert Enum.at(ordered_labels, 1) == {unit1.resource_id, "Unit 1: Unit 1"}

      assert Enum.at(ordered_labels, 2) ==
               {unit1_module1.resource_id, "Module 1: Unit 1 Module 1"}

      assert Enum.at(ordered_labels, 3) ==
               {unit1_module1_section1.resource_id, "Section 1: Unit 1 Module 1 Section 1"}

      assert Enum.at(ordered_labels, 4) ==
               {unit1_module2.resource_id, "Module 2: Unit 1 Module 2"}

      assert Enum.at(ordered_labels, 5) == {unit2.resource_id, "Unit 2: Unit 2"}

      assert Enum.at(ordered_labels, 6) ==
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
                       manually_scheduled: true,
                       removed_from_schedule: false
                     },
                     %{
                       id: scheduled_resources[page4.resource_id].id,
                       scheduling_type: "due_by",
                       start_date: "2023-02-01",
                       end_date: "2023-02-04",
                       manually_scheduled: true,
                       removed_from_schedule: false
                     },
                     %{
                       id: scheduled_resources[page5.resource_id].id,
                       scheduling_type: "due_by",
                       start_date: "2023-02-06",
                       end_date: "2023-02-08",
                       manually_scheduled: true,
                       removed_from_schedule: false
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
      {:ok, _} = Sections.rebuild_contained_pages(section)

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
                           unit_id: ^unit1_resource_id,
                           unit_label: "Unit 1",
                           graded: true,
                           progress: nil,
                           resources: [
                             %ScheduledSectionResource{
                               resource: %Oli.Delivery.Sections.SectionResource{
                                 scheduling_type: :due_by,
                                 manually_scheduled: true,
                                 removed_from_schedule: false,
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
                          unit_id: ^unit1_resource_id,
                          unit_label: "Unit 1",
                          graded: true,
                          progress: nil,
                          resources: [
                            %ScheduledSectionResource{
                              resource: %Oli.Delivery.Sections.SectionResource{
                                scheduling_type: :due_by,
                                manually_scheduled: true,
                                removed_from_schedule: false,
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
                          unit_id: ^unit1_resource_id,
                          unit_label: "Unit 1",
                          graded: true,
                          progress: nil,
                          resources: [
                            %ScheduledSectionResource{
                              resource: %Oli.Delivery.Sections.SectionResource{
                                scheduling_type: :due_by,
                                manually_scheduled: true,
                                removed_from_schedule: false,
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
               Sections.get_ordered_schedule(section, student1.id, nil)
    end
  end

  describe "get_not_scheduled_agenda/2" do
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
    test "get_not_scheduled_agenda", %{
      section: section,
      student1: student1,
      unit1: unit1
    } do
      {:ok, _} = Sections.rebuild_contained_pages(section)

      unit1_resource_id = unit1.resource_id

      assert %{
               {nil, nil} => [
                 %ScheduledContainerGroup{
                   unit_id: ^unit1_resource_id,
                   unit_label: "Unit 1",
                   graded: nil,
                   progress: nil,
                   resources: ordered_resources
                 }
               ]
             } =
               Sections.get_not_scheduled_agenda(section, nil, student1.id)

      # verify that the resources are sorted by hierarchy (numbering index)
      assert [
               "Unscored page one",
               "Scored page two",
               "Assessment 4",
               "Assessment 5",
               "Assessment 3"
             ] =
               Enum.map(ordered_resources, fn res -> res.resource.title end)
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
                     manually_scheduled: true,
                     removed_from_schedule: false
                   },
                   %{
                     id: scheduled_resources[page4.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-04",
                     end_date: "2023-02-06",
                     manually_scheduled: true,
                     removed_from_schedule: false
                   },
                   %{
                     id: scheduled_resources[page5.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-05",
                     end_date: "2023-02-06",
                     manually_scheduled: true,
                     removed_from_schedule: false
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
                     manually_scheduled: true,
                     removed_from_schedule: false
                   },
                   %{
                     id: scheduled_resources[page4.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-05",
                     end_date: "2023-02-07",
                     manually_scheduled: true,
                     removed_from_schedule: false
                   },
                   %{
                     id: scheduled_resources[page5.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-03",
                     end_date: "2023-02-08",
                     manually_scheduled: true,
                     removed_from_schedule: false
                   },
                   %{
                     id: scheduled_resources[scored_page2.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-02",
                     end_date: "2023-02-09",
                     manually_scheduled: true,
                     removed_from_schedule: false
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
                     manually_scheduled: true,
                     removed_from_schedule: false
                   },
                   %{
                     id: scheduled_resources[page4.resource_id].id,
                     scheduling_type: "due_by",
                     start_date: "2023-02-05",
                     end_date: "2023-02-07",
                     manually_scheduled: true,
                     removed_from_schedule: false
                   },
                   %{
                     id: scheduled_resources[page5.resource_id].id,
                     scheduling_type: "read_by",
                     start_date: "2023-02-03",
                     end_date: nil,
                     manually_scheduled: true,
                     removed_from_schedule: false
                   },
                   %{
                     id: scheduled_resources[scored_page2.resource_id].id,
                     scheduling_type: "read_by",
                     start_date: "2023-02-02",
                     end_date: nil,
                     manually_scheduled: true,
                     removed_from_schedule: false
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

  describe "get_container_label_and_numbering/3" do
    setup _ do
      author = insert(:author)
      project = insert(:project, authors: [author])

      # revisions...
      ## section container...
      section_1_revision =
        insert(:revision, %{
          resource_type_id: ResourceType.get_id_by_type("container")
        })

      section_2_revision =
        insert(:revision, %{
          resource_type_id: ResourceType.get_id_by_type("container")
        })

      ## module...
      module_1_revision =
        insert(:revision, %{
          resource_type_id: ResourceType.get_id_by_type("container"),
          children: [section_1_revision.resource_id, section_2_revision.resource_id]
        })

      module_2_revision =
        insert(:revision, %{
          resource_type_id: ResourceType.get_id_by_type("container")
        })

      ## unit...
      unit_1_revision =
        insert(:revision, %{
          resource_type_id: ResourceType.get_id_by_type("container"),
          children: [module_1_revision.resource_id, module_2_revision.resource_id]
        })

      unit_2_revision =
        insert(:revision, %{
          resource_type_id: ResourceType.get_id_by_type("container")
        })

      ## root container...
      container_revision =
        insert(:revision, %{
          resource_type_id: ResourceType.get_id_by_type("container"),
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
               section_1_section_resource.numbering_level,
               section_1_section_resource.numbering_index,
               section.customizations
             ) == "Section 1"

      assert Sections.get_container_label_and_numbering(
               section_2_section_resource.numbering_level,
               section_2_section_resource.numbering_index,
               section.customizations
             ) == "Section 2"

      assert Sections.get_container_label_and_numbering(
               module_1_section_resource.numbering_level,
               module_1_section_resource.numbering_index,
               section.customizations
             ) == "Module 1"

      assert Sections.get_container_label_and_numbering(
               module_2_section_resource.numbering_level,
               module_2_section_resource.numbering_index,
               section.customizations
             ) == "Module 2"

      assert Sections.get_container_label_and_numbering(
               unit_1_section_resource.numbering_level,
               unit_1_section_resource.numbering_index,
               section.customizations
             ) == "Unit 1"

      assert Sections.get_container_label_and_numbering(
               unit_2_section_resource.numbering_level,
               unit_2_section_resource.numbering_index,
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
               section_1_section_resource.numbering_level,
               section_1_section_resource.numbering_index,
               custom_labels
             ) == "Lesson 1"

      assert Sections.get_container_label_and_numbering(
               section_2_section_resource.numbering_level,
               section_2_section_resource.numbering_index,
               custom_labels
             ) == "Lesson 2"

      assert Sections.get_container_label_and_numbering(
               module_1_section_resource.numbering_level,
               module_1_section_resource.numbering_index,
               custom_labels
             ) == "Chapter 1"

      assert Sections.get_container_label_and_numbering(
               module_2_section_resource.numbering_level,
               module_2_section_resource.numbering_index,
               custom_labels
             ) == "Chapter 2"

      assert Sections.get_container_label_and_numbering(
               unit_1_section_resource.numbering_level,
               unit_1_section_resource.numbering_index,
               custom_labels
             ) == "Volume 1"

      assert Sections.get_container_label_and_numbering(
               unit_2_section_resource.numbering_level,
               unit_2_section_resource.numbering_index,
               custom_labels
             ) == "Volume 2"
    end
  end

  describe "get_last_open_and_unfinished_page/2" do
    setup [:create_elixir_project]

    test "returns nil when no pages are open", %{section: section} do
      user = insert(:user)
      refute Sections.get_last_open_and_unfinished_page(section, user.id)
    end

    test "returns last open and unfinished page", %{
      section: section,
      page_1: page_1,
      page_3: page_3
    } do
      user = insert(:user)
      stub_current_time(~U[2023-11-04 20:00:00Z])

      # Initiate attempt for page 1
      initiate_resource_attempt(page_1, user, section)
      set_progress(section.id, page_1.resource_id, user.id, 1.0, page_1)

      # Initiate attempt for page 3
      initiate_resource_attempt(page_3, user, section)
      set_progress(section.id, page_3.resource_id, user.id, 0.9, page_3)

      page = Sections.get_last_open_and_unfinished_page(section, user.id)

      # Returns page 3 since it is the last open and unfinished page
      assert page.slug == page_3.slug
    end
  end

  describe "get_nearest_upcoming_lessons/3" do
    setup [:create_elixir_project]

    test "returns empty list if there are no upcoming lessons", %{section: section} do
      stub_current_time(~U[2024-01-01 00:00:00Z])
      assert Sections.get_nearest_upcoming_lessons(section, insert(:user).id, 1) == []
    end

    test "returns the nearest upcoming lesson", %{section: section, page_3: page_3} do
      stub_current_time(~U[2023-11-03 00:00:00Z])

      [page] = Sections.get_nearest_upcoming_lessons(section, insert(:user).id, 1)

      assert page.slug == page_3.slug
    end

    test "returns empty list if all lessons are in progress", %{section: section, page_3: page_3} do
      stub_current_time(~U[2023-11-03 00:00:00Z])
      user = insert(:user)
      set_progress(section.id, page_3.resource_id, user.id, 0.5, page_3)

      assert Sections.get_nearest_upcoming_lessons(section, user.id, 1) == []
    end
  end

  describe "fetch_all_modules/1" do
    setup [:create_elixir_project]

    test "returns all non-deleted modules for the specified section slug",
         %{
           section: section,
           module_1: module_1,
           module_2: module_2,
           deleted_module: deleted_module
         } do
      result = Sections.fetch_all_modules(section.slug) |> Enum.map(& &1.id)
      assert length(result) == 2

      # Deleted module is not returned
      refute deleted_module.id in result

      # Module 1 and Module 2 are returned
      assert module_1.id in result
      assert module_2.id in result
    end

    test "returns an empty list when there are no matching revisions" do
      assert Sections.fetch_all_modules("non-existent-section") == []
    end
  end

  describe "get_ordered_containers_per_page/1" do
    setup [:create_elixir_project]

    test "fetches and orders containers by numbering level", %{section: section} = context do
      result = Sections.get_ordered_containers_per_page(section)
      # There are exactly 4 pages
      assert length(result) == 4

      # Page 1 and Page 2 have same containers
      for {_, page} <- Map.take(context, [:page_1, :page_2]) do
        assert Enum.find(result, fn pc -> pc[:page_id] == page.resource_id end) == %{
                 page_id: page.resource_id,
                 containers: [
                   %{
                     "id" => context.unit_1.resource_id,
                     "title" => context.unit_1.title,
                     "numbering_level" => 1
                   },
                   %{
                     "id" => context.module_1.resource_id,
                     "title" => context.module_1.title,
                     "numbering_level" => 2
                   }
                 ]
               }
      end

      # Page 3
      assert Enum.find(result, fn pc -> pc[:page_id] == context.page_3.resource_id end) == %{
               page_id: context.page_3.resource_id,
               containers: [
                 %{
                   "id" => context.unit_1.resource_id,
                   "title" => context.unit_1.title,
                   "numbering_level" => 1
                 },
                 %{
                   "id" => context.module_2.resource_id,
                   "title" => context.module_2.title,
                   "numbering_level" => 2
                 }
               ]
             }

      # Page 4 (in root container)
      refute Enum.member?(result, fn pc -> pc[:page_id] == context.page_4.resource_id end)
    end

    test "fetches only specified page ids",
         %{section: section, page_1: page_1} = context do
      result = Sections.get_ordered_containers_per_page(section, [page_1.resource_id])
      assert length(result) == 1

      # Only Page 1 is returned
      assert Enum.find(result, fn pc -> pc[:page_id] == page_1.resource_id end) == %{
               page_id: page_1.resource_id,
               containers: [
                 %{
                   "id" => context.unit_1.resource_id,
                   "title" => context.unit_1.title,
                   "numbering_level" => 1
                 },
                 %{
                   "id" => context.module_1.resource_id,
                   "title" => context.module_1.title,
                   "numbering_level" => 2
                 }
               ]
             }

      # Pages 2, 3 and 4 are not returned
      for {_, page} <- Map.take(context, [:page_2, :page_3, :page_4]) do
        refute Enum.member?(result, fn pc -> pc[:page_id] == page.resource_id end)
      end
    end
  end

  describe "container_titles/1" do
    setup [:create_elixir_project]

    test "returns a map of resource IDs to titles for container resources", %{
      section: section,
      module_1: module_1,
      module_2: module_2,
      unit_1: unit_1
    } do
      result = Sections.container_titles(section)

      assert Map.get(result, unit_1.resource_id) == unit_1.title
      assert Map.get(result, module_1.resource_id) == module_1.title
      assert Map.get(result, module_2.resource_id) == module_2.title
    end
  end

  describe "get_last_completed_or_started_assignments/3" do
    setup [:create_elixir_project]

    test "returns empty list if there are no completed or started pages", %{section: section} do
      assert Sections.get_last_completed_or_started_assignments(section, insert(:user).id, 3) ==
               []
    end

    test "returns last completed or started pages", %{
      section: section,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4
    } do
      user = insert(:user)

      stub_current_time(~U[2024-04-22 20:00:00Z])

      set_progress(section.id, page_1.resource_id, user.id, 1.0, page_1,
        attempt_state: :evaluated,
        updated_at: ~U[2024-04-22 20:00:00Z]
      )

      stub_current_time(~U[2024-04-22 21:00:00Z])

      set_progress(section.id, page_2.resource_id, user.id, 0.5, page_2,
        attempt_state: :evaluated,
        updated_at: ~U[2024-04-22 21:00:00Z]
      )

      set_progress(section.id, page_3.resource_id, user.id, 0.3, page_3,
        attempt_state: :evaluated,
        updated_at: ~U[2024-04-22 22:00:00Z]
      )

      set_progress(section.id, page_4.resource_id, user.id, 0.5, page_4,
        attempt_state: :evaluated,
        updated_at: ~U[2024-04-22 22:30:00Z]
      )

      # Insert active resource attempt for Page 4
      initiate_resource_attempt(page_4, user, section, ~U[2024-04-22 23:00:00Z])

      [last_page, second_last_page] =
        Sections.get_last_completed_or_started_assignments(section, user.id, 2)

      # Returns Page 4 since it is the last started page
      assert last_page.slug == page_4.slug
      assert last_page.progress == 0.5
      assert last_page.score == 5.0
      assert last_page.out_of == 10.0
      assert last_page.last_attempt_state == :active

      # Returns Page 3 since it is the second last completed page
      assert second_last_page.slug == page_3.slug
      assert second_last_page.progress == 0.3
      assert second_last_page.score == 5.0
      assert second_last_page.out_of == 10.0
      assert second_last_page.last_attempt_state == :evaluated
    end
  end

  describe "get_last_attempt_per_page_id/2" do
    setup do
      data = create_elixir_project(%{})

      # Enroll student
      user = insert(:user)
      Sections.enroll(user.id, data.section.id, [ContextRoles.get_role(:context_learner)])

      # Create attempts for resources
      set_progress(
        data.section.id,
        data.page_1.resource_id,
        user.id,
        1.0,
        data.page_1,
        attempt_state: :evaluated
      )

      set_progress(
        data.section.id,
        data.page_2.resource_id,
        user.id,
        1.0,
        data.page_2,
        attempt_state: :evaluated
      )

      # Newer attempt
      set_progress(data.section.id, data.page_2.resource_id, user.id, 0.5, data.page_2,
        attempt_state: :active
      )

      Map.put(data, :user, user)
    end

    test "fetches the latest attempt for each resource within a section", %{
      section: section,
      user: user,
      page_1: page_1,
      page_2: page_2
    } do
      result = Sections.get_last_attempt_per_page_id(section.slug, user.id)
      assert length(result) == 2
      # Check that the results contain the latest attempt states and ids
      assert Enum.any?(result, fn {id, %{state: state}} ->
               id == page_1.resource_id and state == :evaluated
             end)

      # Check that only the latest attempts are returned
      assert Enum.any?(result, fn {id, %{state: state}} ->
               id == page_2.resource_id and state == :active
             end)
    end

    test "returns an empty list when there are no attempts for the user", %{section: section} do
      invalid_user_id = -1
      assert Sections.get_last_attempt_per_page_id(section.slug, invalid_user_id) == []
    end

    test "returns an empty list when section does not exist", %{user: user} do
      assert Sections.get_last_attempt_per_page_id("invalid_section", user.id) == []
    end
  end

  describe "get_sections_containing_resources_of_given_project/1" do
    setup [:create_elixir_project, :create_maths_project]

    test "returns sections containing resources of the given project", %{
      maths_section: maths_section,
      project: elixir_project,
      publication: elixir_publication,
      maths_project: maths_project
    } do
      # the maths course has some content that belongs to the elixir project
      # (in other words, the maths course has been remixed with some elixir pages)
      insert(:section_project_publication, %{
        section: maths_section,
        project: elixir_project,
        publication: elixir_publication
      })

      sections_for_elixir_project =
        Sections.get_sections_containing_resources_of_given_project(elixir_project.id)

      assert length(sections_for_elixir_project) == 2

      sections_for_maths_project =
        Sections.get_sections_containing_resources_of_given_project(maths_project.id)

      assert length(sections_for_maths_project) == 1
    end

    test "returns an empty list when there are no sections containing resources of the given project" do
      assert Sections.get_sections_containing_resources_of_given_project(-1) == []
    end
  end

  describe "list_user_open_and_free_sections/1" do
    test "lists the courses the user is enrolled to, sorted by enrollment date descending" do
      user = insert(:user)

      # Create sections
      section_1 = insert(:section, title: "Elixir", open_and_free: true)
      section_2 = insert(:section, title: "Phoenix", open_and_free: true)
      section_3 = insert(:section, title: "LiveView", open_and_free: true)

      # Enroll user to sections in a different order as sections were created
      insert(:enrollment, %{
        section: section_2,
        user: user,
        inserted_at: ~U[2023-01-01 00:00:00Z],
        updated_at: ~U[2023-01-01 00:00:00Z]
      })

      insert(:enrollment, %{
        section: section_3,
        user: user,
        inserted_at: ~U[2023-01-02 00:00:00Z],
        updated_at: ~U[2023-01-02 00:00:00Z]
      })

      insert(:enrollment, %{
        section: section_1,
        user: user,
        inserted_at: ~U[2023-01-03 00:00:00Z],
        updated_at: ~U[2023-01-03 00:00:00Z]
      })

      # function returns sections sorted by enrollment date descending
      [s1, s3, s2] = Sections.list_user_open_and_free_sections(user)

      assert s1.title == "Elixir"
      assert s3.title == "LiveView"
      assert s2.title == "Phoenix"
    end

    test "retrieve open_and_free active sections by roles" do
      user = insert(:user)

      # Create sections
      section_1 = insert(:section, title: "Elixir", open_and_free: true, status: :active)
      section_2 = insert(:section, title: "Phoenix", open_and_free: true, status: :active)
      section_3 = insert(:section, title: "LiveView", open_and_free: true, status: :archived)

      Sections.enroll(user.id, section_1.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
      ])

      Sections.enroll(user.id, section_2.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
      ])

      Sections.enroll(user.id, section_3.id, [
        Lti_1p3.Roles.ContextRoles.get_role(:context_learner)
      ])

      sections =
        Sections.get_open_and_free_active_sections_by_roles(user.id, [
          Lti_1p3.Roles.ContextRoles.get_role(:context_learner),
          Lti_1p3.Roles.ContextRoles.get_role(:context_instructor)
        ])

      assert length(sections) == 2
      section_ids = Enum.map(sections, & &1.id)
      assert section_1.id in section_ids
      assert section_2.id in section_ids
    end
  end

  describe "get_enrollment/2" do
    test "returns the enrollment for the specified section and user when the status is :enrolled" do
      user = insert(:user)
      section = insert(:section)

      insert(:enrollment, %{
        user: user,
        section: section,
        status: :enrolled
      })

      enrollment = Sections.get_enrollment(section.slug, user.id)
      assert enrollment.status == :enrolled
      assert enrollment.section_id == section.id
      assert enrollment.user_id == user.id

      # enrolments with status different than :enrolled are not returned
      user_2 = insert(:user)

      insert(:enrollment, %{
        user: user_2,
        section: section,
        status: :pending_confirmation
      })

      refute Sections.get_enrollment(section.slug, user_2.id)
    end

    test "returns the enrollment for the specified section when the opts is filter_by_status = false" do
      user = insert(:user)
      section = insert(:section)

      insert(:enrollment, %{
        user: user,
        section: section,
        status: :enrolled
      })

      enrollment = Sections.get_enrollment(section.slug, user.id, filter_by_status: false)
      assert enrollment.status == :enrolled
      assert enrollment.section_id == section.id
      assert enrollment.user_id == user.id

      user_2 = insert(:user)

      insert(:enrollment, %{
        user: user_2,
        section: section,
        status: :pending_confirmation
      })

      enrollment_2 = Sections.get_enrollment(section.slug, user_2.id, filter_by_status: false)
      assert enrollment_2.status == :pending_confirmation
      assert enrollment_2.section_id == section.id
      assert enrollment_2.user_id == user_2.id
    end
  end

  describe "enroll/3" do
    test "enrolls a list of users to a section with the specified roles and status :enrolled by default" do
      user_1 = insert(:user)
      user_2 = insert(:user)
      section = insert(:section)

      Sections.enroll([user_1.id, user_2.id], section.id, [
        ContextRoles.get_role(:context_learner)
      ])

      user_1_enrollment =
        Sections.get_enrollment(section.slug, user_1.id) |> Oli.Repo.preload(:context_roles)

      user_2_enrollment =
        Sections.get_enrollment(section.slug, user_2.id) |> Oli.Repo.preload(:context_roles)

      assert user_1_enrollment.status == :enrolled
      assert user_1_enrollment.section_id == section.id

      assert hd(user_2_enrollment.context_roles).uri ==
               "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"

      assert user_2_enrollment.status == :enrolled
      assert user_2_enrollment.section_id == section.id

      assert hd(user_2_enrollment.context_roles).uri ==
               "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
    end
  end

  describe "enroll/4" do
    test "enrolls a list of users to a section with the specified roles and defined status" do
      user_1 = insert(:user)
      user_2 = insert(:user)
      section = insert(:section)

      Sections.enroll(
        [user_1.id, user_2.id],
        section.id,
        [ContextRoles.get_role(:context_learner)],
        :pending_confirmation
      )

      user_1_enrollment =
        Sections.get_enrollment(section.slug, user_1.id, filter_by_status: false)
        |> Oli.Repo.preload(:context_roles)

      user_2_enrollment =
        Sections.get_enrollment(section.slug, user_2.id, filter_by_status: false)
        |> Oli.Repo.preload(:context_roles)

      assert user_1_enrollment.status == :pending_confirmation
      assert user_1_enrollment.section_id == section.id

      assert hd(user_2_enrollment.context_roles).uri ==
               "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"

      assert user_2_enrollment.status == :pending_confirmation
      assert user_2_enrollment.section_id == section.id

      assert hd(user_2_enrollment.context_roles).uri ==
               "http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"
    end
  end

  describe "get_enrollments_by_emails/2" do
    test "returns enrollments for the specified section and emails" do
      user_1 = insert(:user)
      user_2 = insert(:user)
      user_3 = insert(:user)
      section = insert(:section)

      Sections.enroll(
        [user_1.id, user_2.id],
        section.id,
        [ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Sections.enroll(
        [user_3.id],
        section.id,
        [ContextRoles.get_role(:context_learner)],
        :pending_confirmation
      )

      enrollments = Sections.get_enrollments_by_emails(section.slug, [user_1.email, user_2.email])

      assert length(enrollments) == 2
      assert Enum.all?(enrollments, fn e -> e.status == :enrolled end)
    end
  end

  describe "bulk_update_enrollment_status/3" do
    test "updates the status of enrollments for the specified section and emails" do
      user_1 = insert(:user)
      user_2 = insert(:user)
      user_3 = insert(:user)
      section = insert(:section)

      Sections.enroll(
        [user_1.id, user_2.id],
        section.id,
        [ContextRoles.get_role(:context_learner)],
        :enrolled
      )

      Sections.enroll(
        [user_3.id],
        section.id,
        [ContextRoles.get_role(:context_learner)],
        :pending_confirmation
      )

      Sections.bulk_update_enrollment_status(
        section.slug,
        [user_1.email, user_2.email, user_3.email],
        :suspended
      )

      enrollments =
        Sections.get_enrollments_by_emails(section.slug, [
          user_1.email,
          user_2.email,
          user_3.email
        ])

      assert length(enrollments) == 3
      assert Enum.all?(enrollments, fn e -> e.status == :suspended end)
    end
  end

  describe "get_section_resources_with_lti_activities/1" do
    setup do
      section = insert(:section)

      lti_deployment = insert(:lti_external_tool_activity_deployment)

      activity_registration =
        insert(:activity_registration,
          lti_external_tool_activity_deployment: lti_deployment
        )

      lti_activity_revision =
        insert(:revision,
          activity_type_id: activity_registration.id
        )

      lti_activity_resource = lti_activity_revision.resource

      lti_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: lti_activity_resource.id,
          revision_id: lti_activity_revision.id
        )

      page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: [lti_activity_resource.id]
        )

      page_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: page_revision.resource_id,
          revision_id: page_revision.id
        )

      %{
        section: section,
        lti_activity_resource: lti_activity_resource,
        lti_section_resource: lti_section_resource,
        page_section_resource: page_section_resource,
        activity_registration: activity_registration
      }
    end

    test "returns empty map when section has no LTI activities" do
      empty_section = insert(:section)

      result = Sections.get_section_resources_with_lti_activities(empty_section)

      assert result == %{}
    end

    test "returns map of LTI activity registration IDs to section resources", %{
      section: section,
      activity_registration: activity_registration,
      page_section_resource: page_section_resource
    } do
      result = Sections.get_section_resources_with_lti_activities(section)

      assert is_map(result)
      assert map_size(result) == 1
      assert Map.has_key?(result, activity_registration.id)

      section_resources = result[activity_registration.id]
      assert is_list(section_resources)
      assert length(section_resources) == 1
      assert hd(section_resources).id == page_section_resource.id
    end

    test "handles multiple pages referencing the same LTI activity", %{
      section: section,
      lti_activity_resource: lti_activity_resource,
      activity_registration: activity_registration
    } do
      another_page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: [lti_activity_resource.id]
        )

      another_page_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: another_page_revision.resource_id,
          revision_id: another_page_revision.id
        )

      result = Sections.get_section_resources_with_lti_activities(section)

      section_resources = result[activity_registration.id]
      assert length(section_resources) == 2

      section_resource_ids = Enum.map(section_resources, & &1.id)
      assert Enum.member?(section_resource_ids, another_page_section_resource.id)
    end

    test "handles multiple LTI activities referenced by pages", %{
      section: section
    } do
      lti_deployment2 = insert(:lti_external_tool_activity_deployment)

      activity_registration2 =
        insert(:activity_registration,
          lti_external_tool_activity_deployment: lti_deployment2
        )

      lti_activity_revision2 =
        insert(:revision,
          activity_type_id: activity_registration2.id
        )

      lti_activity_resource2 = lti_activity_revision2.resource

      insert(:section_resource,
        section: section,
        resource_id: lti_activity_resource2.id,
        revision_id: lti_activity_revision2.id
      )

      page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: [lti_activity_resource2.id]
        )

      page_section_resource =
        insert(:section_resource,
          section: section,
          resource_id: page_revision.resource_id,
          revision_id: page_revision.id
        )

      result = Sections.get_section_resources_with_lti_activities(section)

      assert map_size(result) == 2
      assert Map.has_key?(result, activity_registration2.id)

      section_resources = result[activity_registration2.id]
      assert length(section_resources) == 1
      assert hd(section_resources).id == page_section_resource.id
    end

    test "ignores pages that don't reference LTI activities", %{
      section: section,
      activity_registration: activity_registration
    } do
      page_revision =
        insert(:revision,
          resource_type_id: ResourceType.id_for_page(),
          activity_refs: []
        )

      insert(:section_resource,
        section: section,
        resource_id: page_revision.resource_id,
        revision_id: page_revision.id
      )

      result = Sections.get_section_resources_with_lti_activities(section)

      assert is_map(result)
      assert map_size(result) == 1
      assert Map.has_key?(result, activity_registration.id)
    end
  end

  describe "create_section_resources/2" do
    setup do
      author = insert(:author)
      project = insert(:project, authors: [author])

      # Create revisions with different retake_mode values
      page_1_revision =
        insert(:revision,
          resource_type_id: ResourceType.get_id_by_type("page"),
          title: "Page 1",
          retake_mode: :normal
        )

      page_2_revision =
        insert(:revision,
          resource_type_id: ResourceType.get_id_by_type("page"),
          title: "Page 2",
          retake_mode: :targeted
        )

      module_1_revision =
        insert(:revision, %{
          resource_type_id: ResourceType.get_id_by_type("container"),
          children: [page_1_revision.resource_id, page_2_revision.resource_id],
          title: "Module 1"
        })

      container_revision =
        insert(:revision, %{
          resource_type_id: ResourceType.get_id_by_type("container"),
          children: [module_1_revision.resource_id],
          title: "Root Container"
        })

      all_revisions = [page_1_revision, page_2_revision, module_1_revision, container_revision]

      Enum.each(all_revisions, fn revision ->
        insert(:project_resource, %{
          project_id: project.id,
          resource_id: revision.resource_id
        })
      end)

      publication =
        insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

      Enum.each(all_revisions, fn revision ->
        insert(:published_resource, %{
          publication: publication,
          resource: revision.resource,
          revision: revision,
          author: author
        })
      end)

      section =
        insert(:section,
          base_project: project,
          title: "Test Course"
        )

      %{
        section: section,
        publication: publication,
        page_1_revision: page_1_revision,
        page_2_revision: page_2_revision
      }
    end

    test "creates all section resources for the section and publication", %{
      section: section,
      publication: publication
    } do
      {:ok, section} = Sections.create_section_resources(section, publication)
      section_resources = Sections.get_section_resources(section.id)
      assert length(section_resources) == 4
    end

    test "section resources have correct retake_mode from revision", %{
      section: section,
      publication: publication,
      page_1_revision: page_1_revision,
      page_2_revision: page_2_revision
    } do
      {:ok, section} = Sections.create_section_resources(section, publication)
      sr1 = Sections.get_section_resource(section.id, page_1_revision.resource_id)
      sr2 = Sections.get_section_resource(section.id, page_2_revision.resource_id)
      assert sr1.retake_mode == :normal
      assert sr2.retake_mode == :targeted
    end
  end
end
