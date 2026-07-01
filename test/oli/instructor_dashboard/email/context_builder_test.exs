defmodule Oli.InstructorDashboard.Email.ContextBuilderTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Email.{ContextBuilder, EmailContext}

  defp valid_recipient(overrides \\ %{}) do
    Map.merge(
      %{
        student_id: 101,
        email: "alex@example.com",
        given_name: "Alex",
        family_name: "Kim",
        progress_pct: 45.0,
        proficiency_pct: 50.0,
        activity_status: :active,
        last_interaction_at: ~U[2026-05-01 10:00:00Z]
      },
      overrides
    )
  end

  defp valid_input(overrides \\ %{}) do
    Map.merge(
      %{
        section_id: 42,
        course_title: "Intro to Gardening",
        instructor_name: "Dr. Sage",
        instructor_email: "sage@example.edu",
        scope_label: "Module 3",
        situation_key: :struggling_students,
        recipients: [valid_recipient()]
      },
      overrides
    )
  end

  describe "build/1 — happy path" do
    test "returns EmailContext struct with required fields and default tone :neutral" do
      assert {:ok, %EmailContext{} = ctx} = ContextBuilder.build(valid_input())

      assert ctx.section_id == 42
      assert ctx.course_title == "Intro to Gardening"
      assert ctx.instructor_name == "Dr. Sage"
      assert ctx.instructor_email == "sage@example.edu"
      assert ctx.scope_label == "Module 3"
      assert ctx.situation_key == :struggling_students
      assert ctx.recipient_count == 1
      assert ctx.tone == :neutral
      assert ctx.assessment == nil
      assert ctx.objective == nil
      assert ctx.content_item == nil
      assert ctx.support_bucket == nil
    end

    test "respects explicit :neutral / :encouraging / :firm tone" do
      for tone <- [:neutral, :encouraging, :firm] do
        assert {:ok, %EmailContext{tone: ^tone}} =
                 ContextBuilder.build(valid_input(%{tone: tone}))
      end
    end

    test "preserves recipient list and computes recipient_count" do
      recipients = [
        valid_recipient(%{student_id: 1, email: "a@example.com"}),
        valid_recipient(%{student_id: 2, email: "b@example.com"}),
        valid_recipient(%{student_id: 3, email: "c@example.com"})
      ]

      assert {:ok, %EmailContext{recipients: ^recipients, recipient_count: 3}} =
               ContextBuilder.build(valid_input(%{recipients: recipients}))
    end

    test "carries optional :assessment when provided" do
      assessment = %{title: "Pretest", due_at: ~U[2026-05-10 23:59:59Z]}

      assert {:ok, %EmailContext{assessment: ^assessment}} =
               ContextBuilder.build(valid_input(%{assessment: assessment}))
    end

    test "carries optional :objective when provided" do
      objective = %{title: "Photosynthesis", proficiency_label: "Low"}

      assert {:ok, %EmailContext{objective: ^objective}} =
               ContextBuilder.build(valid_input(%{objective: objective}))
    end

    test "carries optional :content_item when provided" do
      content_item = %{title: "Lesson 1", label: "Intro"}

      assert {:ok, %EmailContext{content_item: ^content_item}} =
               ContextBuilder.build(valid_input(%{content_item: content_item}))
    end

    test "carries optional :support_bucket when provided" do
      bucket = %{label: "Struggling", count: 5}

      assert {:ok, %EmailContext{support_bucket: ^bucket}} =
               ContextBuilder.build(valid_input(%{support_bucket: bucket}))
    end
  end

  describe "build/1 — validation errors" do
    test "missing :section_id" do
      assert {:error, :missing_section_id} =
               ContextBuilder.build(Map.delete(valid_input(), :section_id))
    end

    test "missing :course_title" do
      assert {:error, :missing_course_title} =
               ContextBuilder.build(Map.delete(valid_input(), :course_title))
    end

    test "empty :course_title" do
      assert {:error, :missing_course_title} =
               ContextBuilder.build(valid_input(%{course_title: ""}))
    end

    test "missing :instructor_name" do
      assert {:error, :missing_instructor_name} =
               ContextBuilder.build(Map.delete(valid_input(), :instructor_name))
    end

    test "empty :instructor_name" do
      assert {:error, :missing_instructor_name} =
               ContextBuilder.build(valid_input(%{instructor_name: ""}))
    end

    test "missing :scope_label" do
      assert {:error, :missing_scope_label} =
               ContextBuilder.build(Map.delete(valid_input(), :scope_label))
    end

    test "missing :situation_key" do
      assert {:error, :missing_situation_key} =
               ContextBuilder.build(Map.delete(valid_input(), :situation_key))
    end

    test "invalid :situation_key (atom not in Situation whitelist)" do
      assert {:error, :invalid_situation_key} =
               ContextBuilder.build(valid_input(%{situation_key: :unknown}))
    end

    test "non-atom :situation_key" do
      assert {:error, :invalid_situation_key} =
               ContextBuilder.build(valid_input(%{situation_key: "struggling_students"}))
    end

    test "missing :recipients" do
      assert {:error, :missing_recipients} =
               ContextBuilder.build(Map.delete(valid_input(), :recipients))
    end

    test "empty :recipients list" do
      assert {:error, :empty_recipients} =
               ContextBuilder.build(valid_input(%{recipients: []}))
    end

    test "recipient missing :email reports its index and key" do
      bad_recipient = Map.delete(valid_recipient(), :email)
      recipients = [valid_recipient(), bad_recipient]

      assert {:error, {:invalid_recipient, 1, :email}} =
               ContextBuilder.build(valid_input(%{recipients: recipients}))
    end

    test "recipient with empty :email is rejected" do
      bad_recipient = valid_recipient(%{email: ""})

      assert {:error, {:invalid_recipient, 0, :email}} =
               ContextBuilder.build(valid_input(%{recipients: [bad_recipient]}))
    end

    test "recipient missing :student_id reports its index and key" do
      bad_recipient = Map.delete(valid_recipient(), :student_id)

      assert {:error, {:invalid_recipient, 0, :student_id}} =
               ContextBuilder.build(valid_input(%{recipients: [bad_recipient]}))
    end

    test "non-map recipient reports :not_a_map" do
      assert {:error, {:invalid_recipient, 0, :not_a_map}} =
               ContextBuilder.build(valid_input(%{recipients: ["not a map"]}))
    end

    test "invalid :tone returns :invalid_tone" do
      assert {:error, :invalid_tone} =
               ContextBuilder.build(valid_input(%{tone: :angry}))
    end
  end

  describe "build/1 — section_slug plumbing" do
    test "carries :section_slug into EmailContext when provided" do
      assert {:ok, %EmailContext{section_slug: "math-101"}} =
               ContextBuilder.build(valid_input(%{section_slug: "math-101"}))
    end

    test "defaults :section_slug to nil when absent" do
      assert {:ok, %EmailContext{section_slug: nil}} =
               ContextBuilder.build(valid_input())
    end
  end

  describe "build/1 — recipient name fields accept nil/empty (validator's concern)" do
    test "accepts recipient with given_name nil; key still required" do
      r = valid_recipient(%{given_name: nil})

      assert {:ok, %EmailContext{recipients: [^r]}} =
               ContextBuilder.build(valid_input(%{recipients: [r]}))
    end

    test "accepts recipient with given_name empty string" do
      r = valid_recipient(%{given_name: ""})

      assert {:ok, %EmailContext{recipients: [^r]}} =
               ContextBuilder.build(valid_input(%{recipients: [r]}))
    end

    test "accepts recipient with family_name nil" do
      r = valid_recipient(%{family_name: nil})

      assert {:ok, %EmailContext{recipients: [^r]}} =
               ContextBuilder.build(valid_input(%{recipients: [r]}))
    end

    test "rejects recipient missing :given_name key (presence still required)" do
      r = Map.delete(valid_recipient(), :given_name)

      assert {:error, {:invalid_recipient, 0, :given_name}} =
               ContextBuilder.build(valid_input(%{recipients: [r]}))
    end

    test "still rejects recipient with nil :email (strict value)" do
      r = valid_recipient(%{email: nil})

      assert {:error, {:invalid_recipient, 0, :email}} =
               ContextBuilder.build(valid_input(%{recipients: [r]}))
    end
  end
end
