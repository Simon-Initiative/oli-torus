defmodule Oli.InstructorDashboardTest do
  use Oli.DataCase, async: true

  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.InstructorDashboard
  alias Oli.InstructorDashboard.InstructorDashboardState
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

  describe "has_graded_pages_in_scope?/2" do
    test "returns false when the scope has no graded pages" do
      enrollment = instructor_enrollment_fixture()

      refute InstructorDashboard.has_graded_pages_in_scope?(enrollment.section_id)
      refute InstructorDashboard.has_graded_pages_in_scope?(enrollment.section_id, 999_999)
    end
  end

  defp instructor_enrollment_fixture do
    user = insert(:user)
    section = insert(:section)

    Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])
    Sections.get_enrollment(section.slug, user.id, filter_by_status: false)
  end
end
