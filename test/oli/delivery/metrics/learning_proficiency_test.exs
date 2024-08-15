defmodule Oli.Delivery.Metrics.LearningProficiencyTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Resources.ResourceType

  defp set_snapshot(section, resource, objective, user, result) do
    insert(:snapshot, %{
      section: section,
      resource: resource,
      user: user,
      correct: result,
      objective: objective,
      attempt_number: 1,
      part_attempt_number: 1
    })
  end

  defp set_snapshots(section, resource, objective, user, result) do
    # proficiency calculation requires at least 3 snapshots
    set_snapshot(section, resource, objective, user, result)
    set_snapshot(section, resource, objective, user, result)
    set_snapshot(section, resource, objective, user, result)
  end

  defp create_project(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...

    ## subobjectives
    subobjective_a_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Sub-objective A"
      )

    subobjective_b_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Sub-objective B"
      )

    subobjective_c_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Sub-objective C"
      )

    ## objectives
    objective_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 1"
      )

    objective_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 2"
      )

    objective_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 3"
      )

    objective_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 4"
      )

    objective_5_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 5",
        children: [
          subobjective_a_revision.resource_id,
          subobjective_b_revision.resource_id,
          subobjective_c_revision.resource_id
        ]
      )

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_1_revision.resource_id]},
        title: "Page 1"
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_2_revision.resource_id]},
        title: "Page 2"
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_3_revision.resource_id]},
        title: "Page 3"
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_4_revision.resource_id]},
        title: "Page 4"
      )

    page_5_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        objectives: %{"attached" => [objective_5_revision.resource_id]},
        title: "Page 5"
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Module 1"
      })

    module_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [
          page_3_revision.resource_id,
          page_4_revision.resource_id,
          page_5_revision.resource_id
        ],
        content: %{},
        deleted: false,
        title: "Module 2"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [module_1_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Unit 1"
      })

    unit_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [module_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Unit 2"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [unit_1_revision.resource_id, unit_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Root Container"
      })

    all_revisions =
      [
        subobjective_a_revision,
        subobjective_b_revision,
        subobjective_c_revision,
        objective_1_revision,
        objective_2_revision,
        objective_3_revision,
        objective_4_revision,
        objective_5_revision,
        page_1_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        page_5_revision,
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
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # enroll students to section

    [student_1, student_2] = insert_pair(:user)
    [student_3, student_4] = insert_pair(:user)

    Sections.enroll(student_1.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_2.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_3.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    Sections.enroll(student_4.id, section.id, [
      ContextRoles.get_role(:context_learner)
    ])

    %{
      section: section,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      page_5: page_5_revision,
      subobjective_a: subobjective_a_revision,
      subobjective_b: subobjective_b_revision,
      subobjective_c: subobjective_c_revision,
      page_1_objective: objective_1_revision,
      page_2_objective: objective_2_revision,
      page_3_objective: objective_3_revision,
      page_4_objective: objective_4_revision,
      page_5_objective: objective_5_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      student_4: student_4
    }
  end

  describe "learning proficiency calculations" do
    setup [:create_project]

    test "raw_proficiency_per_learning_objective/1 calculates correctly", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      student_4: student_4,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_1_objective: page_1_obj,
      page_2_objective: page_2_obj,
      page_3_objective: page_3_obj,
      page_4_objective: page_4_obj
    } do
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_2, true)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_3, true)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_4, true)

      set_snapshot(section, page_2.resource, page_2_obj.resource, student_1, true)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_2, false)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_3, true)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_4, true)

      set_snapshot(section, page_3.resource, page_3_obj.resource, student_1, true)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_2, false)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_3, false)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_4, false)

      proficiency_per_learning_objective =
        Metrics.raw_proficiency_per_learning_objective(section)

      # "High"
      assert proficiency_per_learning_objective[page_1_obj.resource.id] ==
               {4.0, 4.0}

      # "Medium"
      assert proficiency_per_learning_objective[page_2_obj.resource.id] ==
               {3.0, 4.0}

      # "Low"
      assert proficiency_per_learning_objective[page_3_obj.resource.id] ==
               {1.0, 4.0}

      assert proficiency_per_learning_objective[page_4_obj.resource.id] ==
               nil
    end

    test "raw_proficiency_for_student_per_learning_objective/2 calculates correctly", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4,
      page_1_objective: page_1_obj,
      page_2_objective: page_2_obj,
      page_3_objective: page_3_obj,
      page_4_objective: page_4_obj
    } do
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_1, false)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_1, true)

      set_snapshot(section, page_1.resource, page_1_obj.resource, student_2, false)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_2, false)
      set_snapshot(section, page_4.resource, page_4_obj.resource, student_2, true)

      student_1_proficiency_per_learning_objective =
        Metrics.raw_proficiency_for_student_per_learning_objective(section, student_1.id)

      student_2_proficiency_per_learning_objective =
        Metrics.raw_proficiency_for_student_per_learning_objective(section, student_2.id)

      # "High"
      assert student_1_proficiency_per_learning_objective[page_1_obj.resource.id] == {1.0, 1.0}
      # "Low"
      assert student_1_proficiency_per_learning_objective[page_2_obj.resource.id] == {0.0, 1.0}
      # "High"
      assert student_1_proficiency_per_learning_objective[page_3_obj.resource.id] == {1.0, 1.0}
      assert student_1_proficiency_per_learning_objective[page_4_obj.resource.id] == nil

      # "Low"
      assert student_2_proficiency_per_learning_objective[page_1_obj.resource.id] == {0.0, 1.0}
      assert student_2_proficiency_per_learning_objective[page_2_obj.resource.id] == nil
      # "Low"
      assert student_2_proficiency_per_learning_objective[page_3_obj.resource.id] == {0.0, 1.0}
      # "High"
      assert student_2_proficiency_per_learning_objective[page_4_obj.resource.id] == {1.0, 1.0}
    end

    test "proficiency_per_container/1 calculates correctly", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      student_4: student_4,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4,
      page_1_objective: page_1_obj,
      page_2_objective: page_2_obj,
      page_3_objective: page_3_obj,
      page_4_objective: page_4_obj,
      unit_1: unit_1,
      unit_2: unit_2,
      module_1: module_1,
      module_2: module_2
    } do
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_2, true)
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_3, true)
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_4, true)

      set_snapshots(section, page_2.resource, page_2_obj.resource, student_1, true)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_2, false)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_3, false)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_4, false)

      set_snapshots(section, page_3.resource, page_3_obj.resource, student_1, false)
      set_snapshots(section, page_3.resource, page_3_obj.resource, student_2, true)
      set_snapshots(section, page_3.resource, page_3_obj.resource, student_3, false)
      set_snapshots(section, page_3.resource, page_3_obj.resource, student_4, false)

      set_snapshots(section, page_4.resource, page_4_obj.resource, student_1, false)
      set_snapshots(section, page_4.resource, page_4_obj.resource, student_2, true)
      set_snapshots(section, page_4.resource, page_4_obj.resource, student_3, false)
      set_snapshots(section, page_4.resource, page_4_obj.resource, student_4, false)

      proficiency_per_container =
        Metrics.proficiency_per_container(
          section,
          Oli.Delivery.Sections.get_contained_pages(section)
        )

      assert proficiency_per_container[unit_1.resource_id] == "Medium"
      assert proficiency_per_container[module_1.resource_id] == "Medium"
      assert proficiency_per_container[unit_2.resource_id] == "Low"
      assert proficiency_per_container[module_2.resource_id] == "Low"
    end

    test "proficiency_per_student_across/2 calculates correctly", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      student_4: student_4,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4,
      page_1_objective: page_1_obj,
      page_2_objective: page_2_obj,
      page_3_objective: page_3_obj,
      page_4_objective: page_4_obj,
      unit_1: unit_1
    } do
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_2, true)
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_3, true)

      set_snapshots(section, page_2.resource, page_2_obj.resource, student_1, true)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_2, false)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_3, false)

      set_snapshots(section, page_3.resource, page_3_obj.resource, student_1, true)
      set_snapshots(section, page_3.resource, page_3_obj.resource, student_2, true)
      set_snapshots(section, page_3.resource, page_3_obj.resource, student_3, false)

      set_snapshots(section, page_4.resource, page_4_obj.resource, student_1, true)
      set_snapshots(section, page_4.resource, page_4_obj.resource, student_2, true)
      set_snapshots(section, page_4.resource, page_4_obj.resource, student_3, false)

      proficiency_per_student_across = Metrics.proficiency_per_student_across(section)

      assert proficiency_per_student_across[student_1.id] == "High"
      assert proficiency_per_student_across[student_2.id] == "Medium"
      assert proficiency_per_student_across[student_3.id] == "Low"
      assert proficiency_per_student_across[student_4.id] == nil

      proficiency_per_student_across_unit_1 =
        Metrics.proficiency_per_student_across(section, unit_1.resource_id)

      assert proficiency_per_student_across_unit_1[student_1.id] == "High"
      assert proficiency_per_student_across_unit_1[student_2.id] == "Low"
      assert proficiency_per_student_across_unit_1[student_3.id] == "Low"
      assert proficiency_per_student_across_unit_1[student_4.id] == nil
    end

    test "proficiency_for_student_per_container/2 calculates correctly", %{
      section: section,
      student_1: student_1,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_4: page_4,
      page_1_objective: page_1_obj,
      page_2_objective: page_2_obj,
      page_3_objective: page_3_obj,
      page_4_objective: page_4_obj,
      unit_1: unit_1,
      unit_2: unit_2,
      module_1: module_1,
      module_2: module_2
    } do
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_1, true)
      set_snapshots(section, page_3.resource, page_3_obj.resource, student_1, false)
      set_snapshots(section, page_4.resource, page_4_obj.resource, student_1, true)

      proficiency_for_student_1_per_container =
        Metrics.proficiency_for_student_per_container(
          section,
          student_1.id,
          Oli.Delivery.Sections.get_contained_pages(section)
        )

      assert proficiency_for_student_1_per_container[unit_1.resource_id] == "High"
      assert proficiency_for_student_1_per_container[unit_2.resource_id] == "Low"
      assert proficiency_for_student_1_per_container[module_1.resource_id] == "High"
      assert proficiency_for_student_1_per_container[module_2.resource_id] == "Low"
    end

    test "proficiency_per_student_for_page/2 calculates correctly", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      page_1: page_1,
      page_2: page_2,
      page_1_objective: page_1_obj,
      page_2_objective: page_2_obj
    } do
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_1, false)

      page_1_proficiency =
        Metrics.proficiency_per_student_for_page(section, page_1.resource_id)

      page_2_proficiency =
        Metrics.proficiency_per_student_for_page(section, page_2.resource_id)

      assert page_1_proficiency[student_1.id] == "High"
      assert page_2_proficiency[student_1.id] == "Low"

      assert page_1_proficiency[student_2.id] == nil
      assert page_2_proficiency[student_2.id] == nil
    end

    test "proficiency_per_page/2 calculates correctly", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_1_objective: page_1_obj,
      page_2_objective: page_2_obj,
      page_3_objective: page_3_obj
    } do
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_2, true)
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_3, true)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_1, false)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_2, true)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_3, true)
      set_snapshots(section, page_3.resource, page_3_obj.resource, student_1, false)
      set_snapshots(section, page_3.resource, page_3_obj.resource, student_2, false)
      set_snapshots(section, page_3.resource, page_3_obj.resource, student_3, true)

      proficiency_per_page =
        Metrics.proficiency_per_page(section, [
          page_1.resource_id,
          page_2.resource_id,
          page_3.resource_id
        ])

      assert proficiency_per_page[page_1.resource_id] == "High"
      assert proficiency_per_page[page_2.resource_id] == "Medium"
      assert proficiency_per_page[page_3.resource_id] == "Low"
    end

    test "proficiency_for_student_per_page/2 calculates correctly", %{
      section: section,
      student_1: student_1,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_1_objective: page_1_obj,
      page_2_objective: page_2_obj,
      page_3_objective: page_3_obj
    } do
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_1, false)
      set_snapshots(section, page_3.resource, page_3_obj.resource, student_1, false)

      proficiency_for_student_per_page =
        Metrics.proficiency_for_student_per_page(section, student_1.id)

      assert proficiency_for_student_per_page[page_1.resource_id] == "High"
      assert proficiency_for_student_per_page[page_2.resource_id] == "Low"
      assert proficiency_for_student_per_page[page_3.resource_id] == "Low"
    end

    test "proficiency_for_student_per_learning_objective/3 calculates correctly", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_3: student_3,
      page_1: page_1,
      page_2: page_2,
      page_3: page_3,
      page_5: page_5,
      subobjective_a: subobjective_a,
      subobjective_b: subobjective_b,
      subobjective_c: subobjective_c,
      page_1_objective: page_1_obj,
      page_2_objective: page_2_obj,
      page_3_objective: page_3_obj,
      page_4_objective: page_4_obj,
      page_5_objective: page_5_obj
    } do
      set_snapshots(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshots(section, page_2.resource, page_2_obj.resource, student_1, false)
      set_snapshots(section, page_3.resource, page_3_obj.resource, student_1, false)
      set_snapshots(section, page_5.resource, subobjective_a.resource, student_1, true)
      set_snapshots(section, page_5.resource, subobjective_b.resource, student_1, true)
      set_snapshots(section, page_5.resource, subobjective_c.resource, student_1, true)

      proficiency_for_student_per_learning_objective =
        Metrics.proficiency_for_student_per_learning_objective(
          [page_1_obj, page_2_obj, page_3_obj, page_4_obj, page_5_obj],
          student_1.id,
          section
        )

      assert proficiency_for_student_per_learning_objective[page_1_obj.resource_id] == "High"
      assert proficiency_for_student_per_learning_objective[page_2_obj.resource_id] == "Low"
      assert proficiency_for_student_per_learning_objective[page_3_obj.resource_id] == "Low"

      assert proficiency_for_student_per_learning_objective[page_4_obj.resource_id] ==
               "Not enough data"

      assert proficiency_for_student_per_learning_objective[page_5_obj.resource_id] == "High"

      set_snapshots(section, page_5.resource, subobjective_a.resource, student_2, true)
      set_snapshots(section, page_5.resource, subobjective_b.resource, student_2, false)
      set_snapshots(section, page_5.resource, subobjective_c.resource, student_2, true)

      proficiency_for_student_2_per_learning_objective =
        Metrics.proficiency_for_student_per_learning_objective(
          [page_1_obj, page_5_obj],
          student_2.id,
          section
        )

      assert proficiency_for_student_2_per_learning_objective[page_1_obj.resource_id] ==
               "Not enough data"

      refute proficiency_for_student_2_per_learning_objective[page_2_obj.resource_id]

      assert proficiency_for_student_2_per_learning_objective[page_5_obj.resource_id] == "Medium"

      set_snapshots(section, page_5.resource, subobjective_a.resource, student_3, true)
      set_snapshots(section, page_5.resource, subobjective_b.resource, student_3, false)
      set_snapshots(section, page_5.resource, subobjective_c.resource, student_3, false)

      proficiency_for_student_3_per_learning_objective =
        Metrics.proficiency_for_student_per_learning_objective(
          [page_5_obj],
          student_3.id,
          section
        )

      assert proficiency_for_student_3_per_learning_objective[page_5_obj.resource_id] == "Low"
    end
  end
end
