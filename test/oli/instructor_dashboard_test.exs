defmodule Oli.InstructorDashboardTest do
  use Oli.DataCase, async: true

  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.InstructorDashboard
  alias Oli.InstructorDashboard.InstructorDashboardState
  alias Oli.InstructorDashboard.StudentSupportParameterSettings
  alias Oli.InstructorDashboard.StudentSupportParameters
  alias Oli.Repo

  describe "get_state_by_enrollment_id/1" do
    test "returns nil for invalid or missing enrollment ids" do
      assert InstructorDashboard.get_state_by_enrollment_id("not-an-id") == nil
      assert InstructorDashboard.get_state_by_enrollment_id(-1) == nil
    end

    test "returns the persisted state for an enrollment" do
      enrollment = instructor_enrollment_fixture()

      {:ok, state} =
        InstructorDashboard.upsert_state(enrollment.id, %{
          last_viewed_scope: "container:123",
          section_order: ["engagement", "content"],
          collapsed_section_ids: ["content"]
        })

      fetched_state = InstructorDashboard.get_state_by_enrollment_id(enrollment.id)

      assert %InstructorDashboardState{} = fetched_state
      assert fetched_state.id == state.id
      assert fetched_state.section_order == ["engagement", "content"]
      assert fetched_state.collapsed_section_ids == ["content"]
    end
  end

  describe "upsert_state/2" do
    test "creates a new instructor dashboard state" do
      enrollment = instructor_enrollment_fixture()

      assert {:ok, state} =
               InstructorDashboard.upsert_state(enrollment.id, %{
                 last_viewed_scope: "course",
                 section_order: ["engagement", "content"],
                 collapsed_section_ids: ["content"]
               })

      assert state.enrollment_id == enrollment.id
      assert state.last_viewed_scope == "course"
      assert state.section_order == ["engagement", "content"]
      assert state.collapsed_section_ids == ["content"]
    end

    test "updates the existing state for the enrollment" do
      enrollment = instructor_enrollment_fixture()

      assert {:ok, original_state} =
               InstructorDashboard.upsert_state(enrollment.id, %{
                 last_viewed_scope: "course"
               })

      assert {:ok, updated_state} =
               InstructorDashboard.upsert_state(enrollment.id, %{
                 last_viewed_scope: "container:456"
               })

      assert updated_state.id == original_state.id
      assert updated_state.enrollment_id == enrollment.id
      assert updated_state.last_viewed_scope == "container:456"
      assert updated_state.section_order == []
      assert updated_state.collapsed_section_ids == []

      assert Repo.aggregate(InstructorDashboardState, :count, :id) == 1
    end

    test "preserves existing scope when updating layout fields only" do
      enrollment = instructor_enrollment_fixture()

      assert {:ok, original_state} =
               InstructorDashboard.upsert_state(enrollment.id, %{
                 last_viewed_scope: "container:456"
               })

      assert {:ok, updated_state} =
               InstructorDashboard.upsert_state(enrollment.id, %{
                 section_order: ["content", "engagement"],
                 collapsed_section_ids: ["engagement"]
               })

      assert updated_state.id == original_state.id
      assert updated_state.last_viewed_scope == "container:456"
      assert updated_state.section_order == ["content", "engagement"]
      assert updated_state.collapsed_section_ids == ["engagement"]
    end

    test "creates a new state for layout-only updates using the default scope" do
      enrollment = instructor_enrollment_fixture()

      assert {:ok, state} =
               InstructorDashboard.upsert_state(enrollment.id, %{
                 section_order: ["content", "engagement"],
                 collapsed_section_ids: ["engagement"]
               })

      assert state.last_viewed_scope == "course"
      assert state.section_order == ["content", "engagement"]
      assert state.collapsed_section_ids == ["engagement"]
    end

    test "rejects duplicate ids in persisted layout fields" do
      enrollment = instructor_enrollment_fixture()

      assert {:ok, _state} =
               InstructorDashboard.upsert_state(enrollment.id, %{
                 last_viewed_scope: "course",
                 section_order: ["engagement", "content"]
               })

      assert {:error, changeset} =
               InstructorDashboard.upsert_state(enrollment.id, %{
                 section_order: ["content", "content"]
               })

      assert "must not contain duplicate ids" in errors_on(changeset).section_order

      persisted_state = InstructorDashboard.get_state_by_enrollment_id(enrollment.id)

      assert persisted_state.section_order == ["engagement", "content"]
    end
  end

  describe "resolve_section_layout/2" do
    test "returns default layout when no persisted state exists" do
      assert InstructorDashboard.resolve_section_layout(nil, ["engagement", "content"]) == %{
               section_order: ["engagement", "content"],
               collapsed_section_ids: []
             }
    end

    test "drops stale ids, de-duplicates persisted ids, and appends new visible sections" do
      state = %InstructorDashboardState{
        section_order: ["content", "legacy", "content"],
        collapsed_section_ids: ["legacy", "engagement", "engagement"]
      }

      assert InstructorDashboard.resolve_section_layout(state, ["engagement", "content"]) == %{
               section_order: ["content", "engagement"],
               collapsed_section_ids: ["engagement"]
             }
    end
  end

  describe "StudentSupportParameters.get_active_settings/1" do
    test "returns defaults without inserting a row" do
      section = insert(:section)

      assert StudentSupportParameters.get_active_settings(section.id) ==
               StudentSupportParameters.default_settings()

      assert Repo.aggregate(StudentSupportParameterSettings, :count, :id) == 0
    end

    test "returns persisted settings for the section" do
      section = insert(:section)

      assert {:ok, settings} =
               StudentSupportParameters.save_for_section(section.id, %{
                 inactivity_days: 14,
                 struggling_progress_low_lt: 30,
                 struggling_progress_high_gt: 85,
                 struggling_proficiency_lte: 35,
                 excelling_progress_gte: 85,
                 excelling_proficiency_gte: 75
               })

      assert settings == %{
               inactivity_days: 14,
               struggling_progress_low_lt: 30,
               struggling_progress_high_gt: 85,
               struggling_proficiency_lte: 35,
               excelling_progress_gte: 85,
               excelling_proficiency_gte: 75
             }

      assert StudentSupportParameters.get_active_settings(section.id) == settings
    end
  end

  describe "StudentSupportParameters.save_for_section/3" do
    test "inserts and updates one section-scoped row" do
      section = insert(:section)

      assert {:ok, first_settings} =
               StudentSupportParameters.save_for_section(section.id, %{
                 inactivity_days: 14,
                 struggling_progress_low_lt: 35,
                 struggling_progress_high_gt: 85,
                 struggling_proficiency_lte: 35,
                 excelling_progress_gte: 85,
                 excelling_proficiency_gte: 75
               })

      assert {:ok, updated_settings} =
               StudentSupportParameters.save_for_section(section.id, %{
                 inactivity_days: 30,
                 struggling_progress_low_lt: 25,
                 struggling_progress_high_gt: 90,
                 struggling_proficiency_lte: 30,
                 excelling_progress_gte: 90,
                 excelling_proficiency_gte: 80
               })

      assert first_settings.inactivity_days == 14
      assert updated_settings.inactivity_days == 30
      assert updated_settings.excelling_progress_gte == 90
      assert Repo.aggregate(StudentSupportParameterSettings, :count, :id) == 1
    end

    test "settings are shared by section and independent from instructor enrollment" do
      user_a = insert(:user)
      user_b = insert(:user)
      section = insert(:section)

      Sections.enroll(user_a.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user_b.id, section.id, [ContextRoles.get_role(:context_instructor)])

      assert {:ok, saved_settings} =
               StudentSupportParameters.save_for_section(section.id, %{
                 inactivity_days: 90,
                 struggling_progress_low_lt: 20,
                 struggling_progress_high_gt: 95,
                 struggling_proficiency_lte: 25,
                 excelling_progress_gte: 95,
                 excelling_proficiency_gte: 85
               })

      assert StudentSupportParameters.get_active_settings(section.id) == saved_settings
    end

    test "rejects invalid inactivity days" do
      section = insert(:section)

      assert {:error, changeset} =
               StudentSupportParameters.save_for_section(section.id, %{
                 inactivity_days: 21,
                 struggling_progress_low_lt: 40,
                 struggling_progress_high_gt: 80,
                 struggling_proficiency_lte: 40,
                 excelling_progress_gte: 80,
                 excelling_proficiency_gte: 80
               })

      assert "is invalid" in errors_on(changeset).inactivity_days
    end

    test "rejects threshold values outside 0 to 100" do
      section = insert(:section)

      assert {:error, changeset} =
               StudentSupportParameters.save_for_section(section.id, %{
                 inactivity_days: 7,
                 struggling_progress_low_lt: -1,
                 struggling_progress_high_gt: 80,
                 struggling_proficiency_lte: 40,
                 excelling_progress_gte: 80,
                 excelling_proficiency_gte: 101
               })

      assert "must be greater than or equal to 0" in errors_on(changeset).struggling_progress_low_lt
      assert "must be less than or equal to 100" in errors_on(changeset).excelling_proficiency_gte
    end

    test "rejects overlapping progress and proficiency thresholds" do
      section = insert(:section)

      assert {:error, changeset} =
               StudentSupportParameters.save_for_section(section.id, %{
                 inactivity_days: 7,
                 struggling_progress_low_lt: 80,
                 struggling_progress_high_gt: 80,
                 struggling_proficiency_lte: 80,
                 excelling_progress_gte: 80,
                 excelling_proficiency_gte: 80
               })

      assert "must be greater than struggling low progress threshold" in errors_on(changeset).struggling_progress_high_gt

      assert "must be greater than struggling proficiency threshold" in errors_on(changeset).excelling_proficiency_gte
    end

    test "rejects mismatched shared high progress thresholds" do
      section = insert(:section)

      assert {:error, changeset} =
               StudentSupportParameters.save_for_section(section.id, %{
                 inactivity_days: 7,
                 struggling_progress_low_lt: 40,
                 struggling_progress_high_gt: 80,
                 struggling_proficiency_lte: 40,
                 excelling_progress_gte: 70,
                 excelling_proficiency_gte: 80
               })

      assert "must match struggling high progress threshold" in errors_on(changeset).excelling_progress_gte
    end

    test "failed saves preserve existing persisted settings" do
      section = insert(:section)

      assert {:ok, persisted_settings} =
               StudentSupportParameters.save_for_section(section.id, %{
                 inactivity_days: 14,
                 struggling_progress_low_lt: 30,
                 struggling_progress_high_gt: 85,
                 struggling_proficiency_lte: 35,
                 excelling_progress_gte: 85,
                 excelling_proficiency_gte: 75
               })

      assert {:error, _changeset} =
               StudentSupportParameters.save_for_section(section.id, %{
                 inactivity_days: 14,
                 struggling_progress_low_lt: 85,
                 struggling_progress_high_gt: 85,
                 struggling_proficiency_lte: 35,
                 excelling_progress_gte: 85,
                 excelling_proficiency_gte: 75
               })

      assert StudentSupportParameters.get_active_settings(section.id) == persisted_settings
      assert Repo.aggregate(StudentSupportParameterSettings, :count, :id) == 1
    end
  end

  describe "StudentSupportParameters.to_projector_opts/1" do
    test "returns projector-compatible inactivity days and rules" do
      settings = %{
        inactivity_days: 30,
        struggling_progress_low_lt: 25,
        struggling_progress_high_gt: 90,
        struggling_proficiency_lte: 35,
        excelling_progress_gte: 90,
        excelling_proficiency_gte: 85
      }

      assert StudentSupportParameters.to_projector_opts(settings) == [
               inactivity_days: 30,
               rules: %{
                 struggling: %{
                   any: [{:progress, :lt, 25}, {:progress, :gt, 90}],
                   all: [{:proficiency, :lte, 35}]
                 },
                 excelling: %{
                   any: [],
                   all: [{:progress, :gte, 90}, {:proficiency, :gte, 85}]
                 },
                 on_track: %{
                   any: [],
                   all: [{:progress, :gte, 25}, {:proficiency, :gte, 35}]
                 }
               }
             ]
    end
  end

  defp instructor_enrollment_fixture do
    user = insert(:user)
    section = insert(:section)

    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])
    Sections.get_enrollment(section.slug, user.id, filter_by_status: false)
  end
end
