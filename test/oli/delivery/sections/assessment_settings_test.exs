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
  alias Lti_1p3.Tool.ContextRoles

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
             } = result[{:insert_settings_change, key}]

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
             } = result[{:insert_settings_change, key}]

      key = :late_submit
      key_str = "#{key}"
      old_value_str = "#{sr_1.late_submit}"

      assert %SettingsChanges{
               resource_id: ^resource_id,
               user_id: ^user_id,
               key: ^key_str,
               old_value: ^old_value_str,
               new_value: "allow"
             } = result[{:insert_settings_change, key}]

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
             } = result[{:insert_settings_change, key}]

      key = :late_submit
      key_str = "#{key}"
      old_value_str = "#{sr_1.late_submit}"

      assert %SettingsChanges{
               resource_id: ^resource_id,
               user_id: ^user_id,
               key: ^key_str,
               old_value: ^old_value_str,
               new_value: "allow"
             } = result[{:insert_settings_change, key}]

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
             } = result[{:insert_settings_change, key}]

      key = :late_submit
      key_str = "#{key}"
      old_value_str = "#{sr_1.late_submit}"

      assert %SettingsChanges{
               resource_id: ^resource_id,
               user_id: ^user_id,
               key: ^key_str,
               old_value: ^old_value_str,
               new_value: "disallow"
             } = result[{:insert_settings_change, key}]

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
end
