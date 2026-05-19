defmodule Oli.InstructorDashboard.Recommendations.PersistenceTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.InstructorDashboard.Recommendations.{RecommendationFeedback, RecommendationInstance}

  @section_attrs %{
    context_id: "context_id",
    end_date: ~U[2010-05-17 00:00:00.000000Z],
    open_and_free: true,
    registration_open: true,
    requires_enrollment: true,
    start_date: ~U[2010-04-17 00:00:00.000000Z],
    title: "some title"
  }

  describe "recommendation instance persistence" do
    setup do
      map = Seeder.base_project_with_resource2()

      {:ok, section} =
        @section_attrs
        |> Map.put(:base_project_id, map.project.id)
        |> Map.put(:institution_id, map.institution.id)
        |> Oli.Delivery.Sections.create_section()

      instructor = insert(:user)

      {:ok, %{section: section, instructor: instructor}}
    end

    test "persists a course-scoped implicit recommendation instance", %{
      section: section
    } do
      attrs = %{
        section_id: section.id,
        container_type: :course,
        container_id: nil,
        generation_mode: :implicit,
        state: :ready,
        message: "Recommendation text",
        prompt_version: "v1",
        prompt_snapshot: %{scope: "Entire Course"},
        original_prompt: %{"messages" => [%{"role" => "system", "content" => "..."}]},
        response_metadata: %{fallback_reason: nil}
      }

      assert {:ok, record} =
               %RecommendationInstance{}
               |> RecommendationInstance.changeset(attrs)
               |> Repo.insert()

      assert record.section_id == section.id
      assert record.container_type == :course
      assert is_nil(record.container_id)
      assert record.generation_mode == :implicit
      assert record.state == :ready
      assert get_in(record.original_prompt, ["messages"]) != nil
    end

    test "persists a generating instance without a message", %{section: section} do
      attrs = %{
        section_id: section.id,
        container_type: :course,
        container_id: nil,
        generation_mode: :implicit,
        state: :generating,
        message: nil,
        prompt_version: "v1",
        prompt_snapshot: %{scope: "Entire Course"}
      }

      assert {:ok, record} =
               %RecommendationInstance{}
               |> RecommendationInstance.changeset(attrs)
               |> Repo.insert()

      assert record.state == :generating
      assert is_nil(record.message)
    end

    test "rejects a container-scoped instance without container_id", %{section: section} do
      attrs = %{
        section_id: section.id,
        container_type: :container,
        generation_mode: :implicit,
        state: :ready,
        message: "Recommendation text",
        prompt_version: "v1"
      }

      assert {:error, changeset} =
               %RecommendationInstance{}
               |> RecommendationInstance.changeset(attrs)
               |> Repo.insert()

      assert "must match the selected container_type" in errors_on(changeset).container_id
    end

    test "persists an explicit regeneration with a generating instructor", %{
      section: section,
      instructor: instructor
    } do
      attrs = %{
        section_id: section.id,
        container_type: :container,
        container_id: 10462,
        generation_mode: :explicit_regen,
        state: :fallback,
        message: "Fallback recommendation text",
        prompt_version: "v1",
        prompt_snapshot: %{scope: "Module 1"},
        original_prompt: %{"messages" => [%{"role" => "user", "content" => "..."}]},
        response_metadata: %{fallback_reason: :provider_failure},
        generated_by_user_id: instructor.id
      }

      assert {:ok, record} =
               %RecommendationInstance{}
               |> RecommendationInstance.changeset(attrs)
               |> Repo.insert()

      assert record.container_type == :container
      assert record.container_id == 10_462
      assert record.generation_mode == :explicit_regen
      assert record.generated_by_user_id == instructor.id
      assert get_in(record.original_prompt, ["messages"]) != nil
    end
  end

  describe "recommendation feedback persistence" do
    setup do
      map = Seeder.base_project_with_resource2()

      {:ok, section} =
        @section_attrs
        |> Map.put(:base_project_id, map.project.id)
        |> Map.put(:institution_id, map.institution.id)
        |> Oli.Delivery.Sections.create_section()

      instructor = insert(:user)
      other_instructor = insert(:user)

      {:ok, recommendation_instance} =
        %RecommendationInstance{}
        |> RecommendationInstance.changeset(%{
          section_id: section.id,
          container_type: :course,
          generation_mode: :implicit,
          state: :ready,
          message: "Recommendation text",
          prompt_version: "v1"
        })
        |> Repo.insert()

      {:ok,
       %{
         instructor: instructor,
         other_instructor: other_instructor,
         recommendation_instance: recommendation_instance
       }}
    end

    test "enforces one thumbs sentiment per recommendation instance per user", %{
      instructor: instructor,
      recommendation_instance: recommendation_instance
    } do
      assert {:ok, _record} =
               %RecommendationFeedback{}
               |> RecommendationFeedback.changeset(%{
                 recommendation_instance_id: recommendation_instance.id,
                 user_id: instructor.id,
                 feedback_type: :thumbs_up
               })
               |> Repo.insert()

      assert {:error, changeset} =
               %RecommendationFeedback{}
               |> RecommendationFeedback.changeset(%{
                 recommendation_instance_id: recommendation_instance.id,
                 user_id: instructor.id,
                 feedback_type: :thumbs_down
               })
               |> Repo.insert()

      assert "sentiment already submitted for this recommendation" in errors_on(changeset).recommendation_instance_id
    end

    test "allows additional-text feedback alongside thumbs sentiment", %{
      instructor: instructor,
      recommendation_instance: recommendation_instance
    } do
      assert {:ok, _thumbs} =
               %RecommendationFeedback{}
               |> RecommendationFeedback.changeset(%{
                 recommendation_instance_id: recommendation_instance.id,
                 user_id: instructor.id,
                 feedback_type: :thumbs_up
               })
               |> Repo.insert()

      assert {:ok, feedback} =
               %RecommendationFeedback{}
               |> RecommendationFeedback.changeset(%{
                 recommendation_instance_id: recommendation_instance.id,
                 user_id: instructor.id,
                 feedback_type: :additional_text,
                 feedback_text: "This recommendation was too generic."
               })
               |> Repo.insert()

      assert feedback.feedback_type == :additional_text
      assert feedback.feedback_text == "This recommendation was too generic."
    end

    test "allows separate instructors to submit sentiment for the same recommendation", %{
      instructor: instructor,
      other_instructor: other_instructor,
      recommendation_instance: recommendation_instance
    } do
      assert {:ok, _first} =
               %RecommendationFeedback{}
               |> RecommendationFeedback.changeset(%{
                 recommendation_instance_id: recommendation_instance.id,
                 user_id: instructor.id,
                 feedback_type: :thumbs_up
               })
               |> Repo.insert()

      assert {:ok, second} =
               %RecommendationFeedback{}
               |> RecommendationFeedback.changeset(%{
                 recommendation_instance_id: recommendation_instance.id,
                 user_id: other_instructor.id,
                 feedback_type: :thumbs_down
               })
               |> Repo.insert()

      assert second.feedback_type == :thumbs_down
    end
  end
end
