defmodule Oli.Delivery.Sections.AssessmentSettingsTest do
  use ExUnit.Case, async: true
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings.AssessmentSettings
  alias Oli.Delivery.Settings.SettingsChanges
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Repo
  alias Lti_1p3.Roles.ContextRoles

  describe "do_update" do
    setup [:setup_data]

    test "on password", ctx do
      %{sr_1: sr_1, section: section, user: user, assessments: assessments} = ctx

      assessment_setting_id = sr_1.resource_id
      resource_id = sr_1.resource_id
      section_id = section.id
      user_id = user.id

      key = :password
      new_value = "abc123"
      old_value = Map.get(sr_1, key)

      resources = %{section: section, user: user, assessments: assessments}

      {:ok, result} =
        AssessmentSettings.do_update(key, assessment_setting_id, new_value, resources)

      assert result.get_section_resource.id ==
               Repo.get(SectionResource, result.get_section_resource.id).id

      key_str = "#{key}"

      assert %Oli.Delivery.Settings.SettingsChanges{
               resource_id: ^resource_id,
               section_id: ^section_id,
               user_id: ^user_id,
               old_value: ^old_value,
               new_value: ^new_value,
               key: ^key_str
             } = result[{:insert_setting, key}]

      #  Password is updated in the section resource
      refute Map.get(sr_1, key) == Map.get(result.update_section_resource, key)

      password_from_depot =
        SectionResourceDepot.get_section_resource(section_id, assessment_setting_id).password

      password_from_repo = Repo.get(SectionResource, result.get_section_resource.id).password

      # Password is updated in the Depot
      assert password_from_depot == password_from_repo
    end

    test "on late_policy > allow_late_start_and_late_submit", ctx do
      %{sr_1: sr_1, section: section, user: user, assessments: assessments} = ctx

      assessment_setting_id = sr_1.resource_id
      resource_id = sr_1.resource_id

      key = :late_policy
      new_value = :allow_late_start_and_late_submit

      resources = %{section: section, user: user, assessments: assessments}

      {:ok, result} =
        AssessmentSettings.do_update(key, assessment_setting_id, new_value, resources)

      user_id = user.id
      key = :late_start
      key_str = "#{key}"
      old_value_str = "#{sr_1.late_start}"

      assert %SettingsChanges{
               resource_id: ^resource_id,
               user_id: ^user_id,
               key: ^key_str,
               old_value: ^old_value_str,
               new_value: "allow"
             } = result[{:insert_setting, key}]

      key = :late_submit
      key_str = "#{key}"
      old_value_str = "#{sr_1.late_submit}"

      assert %SettingsChanges{
               resource_id: ^resource_id,
               user_id: ^user_id,
               key: ^key_str,
               old_value: ^old_value_str,
               new_value: "allow"
             } = result[{:insert_setting, key}]

      assert %SectionResource{
               late_start: :allow,
               late_submit: :allow
             } =
               result.update_section_resource
    end

    test "late_policy > allow_late_submit_but_not_late_start", ctx do
      %{sr_1: sr_1, section: section, user: user, assessments: assessments} = ctx

      assessment_setting_id = sr_1.resource_id
      resource_id = sr_1.resource_id

      key = :late_policy
      new_value = :allow_late_submit_but_not_late_start

      resources = %{section: section, user: user, assessments: assessments}

      {:ok, result} =
        AssessmentSettings.do_update(key, assessment_setting_id, new_value, resources)

      user_id = user.id
      key = :late_start
      key_str = "#{key}"
      old_value_str = "#{sr_1.late_start}"

      assert %SettingsChanges{
               resource_id: ^resource_id,
               user_id: ^user_id,
               key: ^key_str,
               old_value: ^old_value_str,
               new_value: "disallow"
             } = result[{:insert_setting, key}]

      key = :late_submit
      key_str = "#{key}"
      old_value_str = "#{sr_1.late_submit}"

      assert %SettingsChanges{
               resource_id: ^resource_id,
               user_id: ^user_id,
               key: ^key_str,
               old_value: ^old_value_str,
               new_value: "allow"
             } = result[{:insert_setting, key}]

      assert %SectionResource{
               late_start: :disallow,
               late_submit: :allow
             } =
               result.update_section_resource
    end

    test "late_policy > disallow_late_start_and_late_submit", ctx do
      %{sr_1: sr_1, section: section, user: user, assessments: assessments} = ctx

      assessment_setting_id = sr_1.resource_id
      resource_id = sr_1.resource_id

      key = :late_policy
      new_value = :disallow_late_start_and_late_submit

      resources = %{section: section, user: user, assessments: assessments}

      {:ok, result} =
        AssessmentSettings.do_update(key, assessment_setting_id, new_value, resources)

      user_id = user.id
      key = :late_start
      key_str = "#{key}"
      old_value_str = "#{sr_1.late_start}"

      assert %SettingsChanges{
               resource_id: ^resource_id,
               user_id: ^user_id,
               key: ^key_str,
               old_value: ^old_value_str,
               new_value: "disallow"
             } = result[{:insert_setting, key}]

      key = :late_submit
      key_str = "#{key}"
      old_value_str = "#{sr_1.late_submit}"

      assert %SettingsChanges{
               resource_id: ^resource_id,
               user_id: ^user_id,
               key: ^key_str,
               old_value: ^old_value_str,
               new_value: "disallow"
             } = result[{:insert_setting, key}]

      assert %SectionResource{
               late_start: :disallow,
               late_submit: :disallow
             } =
               result.update_section_resource
    end
  end

  defp setup_data(%{}) do
    user = insert(:user)
    section = insert(:section)

    page = Oli.Resources.ResourceType.id_for_page()

    sr_1 = insert(:section_resource, section: section, resource_type_id: page)

    assessments = create_assessments([sr_1])

    {:ok, _enrollment} =
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

    {:ok, %{section: section, user: user, assessments: assessments, sr_1: sr_1}}
  end

  defp create_assessments(section_resources) do
    {assessments, _counter} =
      Enum.reduce(section_resources, {[], 1}, fn sr, {acc, counter} ->
        settings_combined =
          %{
            index: counter,
            name: "New Assessment #{counter}",
            max_attempts: sr.max_attempts,
            password: sr.password,
            start_date: sr.start_date,
            end_date: sr.end_date,
            scheduling_type: sr.scheduling_type,
            time_limit: sr.time_limit,
            collab_space_config: nil,
            resource_id: sr.resource_id,
            assessment_mode: sr.assessment_mode,
            explanation_strategy: nil,
            feedback_mode: sr.feedback_mode,
            feedback_scheduled_date: sr.feedback_scheduled_date,
            grace_period: sr.grace_period,
            late_start: sr.late_start,
            late_submit: sr.late_submit,
            retake_mode: sr.retake_mode,
            review_submission: sr.review_submission,
            scoring_strategy_id: sr.scoring_strategy_id,
            exceptions_count: 0
          }

        {[settings_combined | acc], counter + 1}
      end)

    Enum.reverse(assessments)
  end

  describe "get_assessments/2" do
    setup [:setup_section_with_hierarchy]

    test "includes name and name_with_container_label fields", %{
      section: section,
      page_in_unit: page_in_unit,
      page_in_root: page_in_root
    } do
      student_exceptions = []
      assessments = AssessmentSettings.get_assessments(section, student_exceptions)

      assert length(assessments) >= 2

      # Find the assessment for the page in a unit
      unit_page_assessment =
        Enum.find(assessments, fn a -> a.resource_id == page_in_unit.resource_id end)

      assert unit_page_assessment.name == page_in_unit.title
      assert unit_page_assessment.name_with_container_label =~ "Unit 1:"
      assert unit_page_assessment.name_with_container_label =~ page_in_unit.title

      # Find the assessment for the page in root
      root_page_assessment =
        Enum.find(assessments, fn a -> a.resource_id == page_in_root.resource_id end)

      assert root_page_assessment.name == page_in_root.title
      assert root_page_assessment.name_with_container_label == page_in_root.title
    end

    test "name_with_container_label respects custom container labels", %{
      section: section,
      page_in_unit: page_in_unit
    } do
      # Update section with custom labels
      customizations = %{unit: "Unidad", module: "Módulo", section: "Sección"}
      {:ok, updated_section} = Sections.update_section(section, %{customizations: customizations})

      student_exceptions = []
      assessments = AssessmentSettings.get_assessments(updated_section, student_exceptions)

      unit_page_assessment =
        Enum.find(assessments, fn a -> a.resource_id == page_in_unit.resource_id end)

      assert unit_page_assessment.name == page_in_unit.title
      assert unit_page_assessment.name_with_container_label =~ "Unidad 1:"
      assert unit_page_assessment.name_with_container_label =~ page_in_unit.title
    end

    test "includes all required fields", %{section: section} do
      student_exceptions = []
      assessments = AssessmentSettings.get_assessments(section, student_exceptions)

      assert length(assessments) > 0

      [first_assessment | _] = assessments

      assert Map.has_key?(first_assessment, :name)
      assert Map.has_key?(first_assessment, :name_with_container_label)
      assert Map.has_key?(first_assessment, :resource_id)
      assert Map.has_key?(first_assessment, :index)
      assert Map.has_key?(first_assessment, :scheduling_type)
      assert Map.has_key?(first_assessment, :exceptions_count)
    end

    test "calculates exceptions_count correctly", %{
      section: section,
      page_in_unit: page_in_unit,
      student: student
    } do
      # Create a student exception
      insert(:delivery_setting,
        section: section,
        resource: page_in_unit.resource,
        user: student
      )

      student_exceptions = AssessmentSettings.get_student_exceptions(section.id)
      assessments = AssessmentSettings.get_assessments(section, student_exceptions)

      unit_page_assessment =
        Enum.find(assessments, fn a -> a.resource_id == page_in_unit.resource_id end)

      assert not is_nil(unit_page_assessment), "Assessment for page_in_unit should be found"
      assert unit_page_assessment.exceptions_count == 1
    end
  end

  defp setup_section_with_hierarchy(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])
    student = insert(:user)

    # Create revisions
    page_in_root_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Root Page",
        graded: true
      )

    page_in_unit_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        title: "Unit Page",
        graded: true
      )

    unit_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        title: "Unit 1",
        children: [page_in_unit_revision.resource_id]
      )

    root_revision =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        title: "Root",
        children: [page_in_root_revision.resource_id, unit_revision.resource_id]
      )

    # Create publication
    publication = insert(:publication, project: project)

    # Publish resources
    insert(:published_resource,
      publication: publication,
      resource: page_in_root_revision.resource,
      revision: page_in_root_revision
    )

    insert(:published_resource,
      publication: publication,
      resource: page_in_unit_revision.resource,
      revision: page_in_unit_revision
    )

    insert(:published_resource,
      publication: publication,
      resource: unit_revision.resource,
      revision: unit_revision
    )

    insert(:published_resource,
      publication: publication,
      resource: root_revision.resource,
      revision: root_revision
    )

    # Create section
    section = insert(:section, base_project: project)

    insert(:section_project_publication,
      section: section,
      project: project,
      publication: publication
    )

    # Create section resources - children must be section_resource IDs, not resource_ids
    page_in_root_sr =
      insert(:section_resource,
        section: section,
        project: project,
        resource_id: page_in_root_revision.resource_id,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        numbering_index: 1
      )

    page_in_unit_sr =
      insert(:section_resource,
        section: section,
        project: project,
        resource_id: page_in_unit_revision.resource_id,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("page"),
        numbering_index: 2
      )

    unit_sr =
      insert(:section_resource,
        section: section,
        project: project,
        resource_id: unit_revision.resource_id,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        numbering_level: 1,
        numbering_index: 1,
        children: [page_in_unit_sr.id]
      )

    root_sr =
      insert(:section_resource,
        section: section,
        project: project,
        resource_id: root_revision.resource_id,
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        numbering_level: 0,
        numbering_index: 1,
        children: [
          page_in_root_sr.id,
          unit_sr.id
        ]
      )

    # Update section with root_section_resource_id
    {:ok, section} = Sections.update_section(section, %{root_section_resource_id: root_sr.id})

    # Rebuild contained_pages - this needs all section_resources with their children
    # It will query section_resources itself, so we don't need to pass them
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # Reload section to ensure it's fresh
    section = Sections.get_section!(section.id)

    {:ok,
     %{
       section: section,
       page_in_root: page_in_root_revision,
       page_in_unit: page_in_unit_revision,
       student: student
     }}
  end
end
