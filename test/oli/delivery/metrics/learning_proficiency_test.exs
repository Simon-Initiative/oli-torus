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
      objective: objective
    })
  end

  defp create_project(_conn) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## objectives
    objective_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 1"
      )

    objective_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 2"
      )

    objective_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 3"
      )

    objective_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("objective"),
        title: "Objective 4"
      )

    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_1_revision.resource_id]},
        title: "Page 1"
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_2_revision.resource_id]},
        title: "Page 2"
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_3_revision.resource_id]},
        title: "Page 3"
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        objectives: %{"attached" => [objective_4_revision.resource_id]},
        title: "Page 4"
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Module 1"
      })

    module_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_3_revision.resource_id, page_4_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Module 2"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Unit 1"
      })

    unit_2_revision =
      insert(:revision, %{
        resource: insert(:resource),
        objectives: %{},
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
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
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [unit_1_revision.resource_id, unit_2_revision.resource_id],
        content: %{},
        deleted: false,
        title: "Root Container"
      })

    # asociate resources to project
    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_3_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: objective_4_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_3_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_4_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: module_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: module_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource_id
    })

    # publish project and resources
    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    insert(:published_resource, %{
      publication: publication,
      resource: objective_1_revision.resource,
      revision: objective_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_2_revision.resource,
      revision: objective_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_3_revision.resource,
      revision: objective_3_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: objective_4_revision.resource,
      revision: objective_4_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_1_revision.resource,
      revision: page_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_2_revision.resource,
      revision: page_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_3_revision.resource,
      revision: page_3_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_4_revision.resource,
      revision: page_4_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: module_1_revision.resource,
      revision: module_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: module_2_revision.resource,
      revision: module_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_1_revision.resource,
      revision: unit_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_2_revision.resource,
      revision: unit_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: author
    })

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
      page_1_objective: objective_1_revision,
      page_2_objective: objective_2_revision,
      page_3_objective: objective_3_revision,
      page_4_objective: objective_4_revision,
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

    test "proficiency_per_learning_objective/1 calculates correctly", %{
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
        Metrics.proficiency_per_learning_objective(section.slug)

      assert proficiency_per_learning_objective[page_1_obj.resource.id] ==
               "High"

      assert proficiency_per_learning_objective[page_2_obj.resource.id] ==
               "Medium"

      assert proficiency_per_learning_objective[page_3_obj.resource.id] ==
               "Low"

      assert proficiency_per_learning_objective[page_4_obj.resource.id] ==
               nil
    end

    test "proficiency_for_student_per_learning_objective/2 calculates correctly", %{
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
        Metrics.proficiency_for_student_per_learning_objective(section.slug, student_1.id)

      student_2_proficiency_per_learning_objective =
        Metrics.proficiency_for_student_per_learning_objective(section.slug, student_2.id)

      assert student_1_proficiency_per_learning_objective[page_1_obj.resource.id] == "High"
      assert student_1_proficiency_per_learning_objective[page_2_obj.resource.id] == "Low"
      assert student_1_proficiency_per_learning_objective[page_3_obj.resource.id] == "High"
      assert student_1_proficiency_per_learning_objective[page_4_obj.resource.id] == nil

      assert student_2_proficiency_per_learning_objective[page_1_obj.resource.id] == "Low"
      assert student_2_proficiency_per_learning_objective[page_2_obj.resource.id] == nil
      assert student_2_proficiency_per_learning_objective[page_3_obj.resource.id] == "Low"
      assert student_2_proficiency_per_learning_objective[page_4_obj.resource.id] == "High"
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
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_2, true)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_3, true)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_4, true)

      set_snapshot(section, page_2.resource, page_2_obj.resource, student_1, true)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_2, false)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_3, false)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_4, false)

      set_snapshot(section, page_3.resource, page_3_obj.resource, student_1, false)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_2, true)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_3, false)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_4, false)

      set_snapshot(section, page_4.resource, page_4_obj.resource, student_1, false)
      set_snapshot(section, page_4.resource, page_4_obj.resource, student_2, true)
      set_snapshot(section, page_4.resource, page_4_obj.resource, student_3, false)
      set_snapshot(section, page_4.resource, page_4_obj.resource, student_4, false)

      proficiency_per_container = Metrics.proficiency_per_container(section.slug)

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
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_2, true)
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_3, true)

      set_snapshot(section, page_2.resource, page_2_obj.resource, student_1, true)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_2, false)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_3, false)

      set_snapshot(section, page_3.resource, page_3_obj.resource, student_1, true)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_2, true)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_3, false)

      set_snapshot(section, page_4.resource, page_4_obj.resource, student_1, true)
      set_snapshot(section, page_4.resource, page_4_obj.resource, student_2, true)
      set_snapshot(section, page_4.resource, page_4_obj.resource, student_3, false)

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
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_1, true)
      set_snapshot(section, page_3.resource, page_3_obj.resource, student_1, false)
      set_snapshot(section, page_4.resource, page_4_obj.resource, student_1, true)

      proficiency_for_student_1_per_container =
        Metrics.proficiency_for_student_per_container(section.slug, student_1.id)

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
      set_snapshot(section, page_1.resource, page_1_obj.resource, student_1, true)
      set_snapshot(section, page_2.resource, page_2_obj.resource, student_1, false)

      page_1_proficiency =
        Metrics.proficiency_per_student_for_page(section.slug, page_1.resource_id)

      page_2_proficiency =
        Metrics.proficiency_per_student_for_page(section.slug, page_2.resource_id)

      assert page_1_proficiency[student_1.id] == "High"
      assert page_2_proficiency[student_1.id] == "Low"

      assert page_1_proficiency[student_2.id] == nil
      assert page_2_proficiency[student_2.id] == nil
    end
  end
end
