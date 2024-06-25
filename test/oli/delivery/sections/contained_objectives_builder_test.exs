defmodule Oli.Delivery.Sections.ContainedObjectivesBuilderTest do
  use Oban.Testing, repo: Oli.Repo
  use Oli.DataCase

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.ContainedObjectivesBuilder
  alias Oli.Factory

  describe "given a section with objectives" do
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
      assert {:ok, _} = perform_job(ContainedObjectivesBuilder, %{section_slug: section.slug})

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
      assert {:ok, _} = perform_job(ContainedObjectivesBuilder, %{section_slug: section.slug})

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

    test "it is idempotent", %{
      section: section,
      resources: resources
    } do
      for _ <- 1..2 do
        assert {:ok, _} = perform_job(ContainedObjectivesBuilder, %{section_slug: section.slug})

        # Check all contained objectives
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
  end

  describe "given a section without objectives" do
    test "it does not insert any contained objective but updates the section state" do
      section = Factory.insert(:section, v25_migration: :not_started)

      assert {:ok, _} = perform_job(ContainedObjectivesBuilder, %{section_slug: section.slug})

      assert Sections.get_section_by(slug: section.slug).v25_migration == :done
      assert [] == Sections.get_section_contained_objectives(section.id, nil)
    end
  end
end
