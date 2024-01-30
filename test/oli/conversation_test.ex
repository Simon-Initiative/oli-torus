defmodule Oli.ConversationTest do
  use Oli.DataCase, async: true

  import Oli.Utils.Seeder.Utils

  alias Oli.Utils.Seeder
  alias Oli.Conversation

  defp setup_conversations(_) do
    # Setup: Create some users, enrollments, context roles, and conversation messages
    %{}
    |> Seeder.Project.create_author(author_tag: :author)
    |> Seeder.Project.create_sample_project(
      ref(:author),
      project_tag: :proj,
      publication_tag: :pub,
      unscored_page1_tag: :unscored_page1,
      scored_page2_tag: :scored_page2
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
    |> Seeder.Section.create_and_enroll_learner(
      ref(:section),
      %{},
      user_tag: :student2
    )
    |> Seeder.Section.create_and_enroll_instructor(
      ref(:section),
      %{},
      user_tag: :instructor1
    )
    |> Seeder.Section.add_assistant_conversation_message(
      ref(:section),
      ref(:student1),
      ref(:unscored_page1),
      :user,
      "Hi, I am a student 1!",
      message_tag: :message1
    )
    |> Seeder.Section.add_assistant_conversation_message(
      ref(:section),
      ref(:student1),
      ref(:unscored_page1),
      :assistant,
      "Hello student 1, and welcome to the course! How may I help you?",
      message_tag: :message1
    )
    |> Seeder.Section.add_assistant_conversation_message(
      ref(:section),
      ref(:student2),
      ref(:unscored_page1),
      :user,
      "Hi, I am a student 2!",
      message_tag: :message1
    )
    |> Seeder.Section.add_assistant_conversation_message(
      ref(:section),
      ref(:student2),
      ref(:unscored_page1),
      :assistant,
      "Hello student 2, and welcome to the course! How may I help you?",
      message_tag: :message1
    )
    |> Seeder.Section.add_assistant_conversation_message(
      ref(:section),
      ref(:student2),
      ref(:unscored_page1),
      :assistant,
      "Hello student 2, how may I help you?",
      message_tag: :message1
    )
    |> Seeder.Section.add_assistant_conversation_message(
      ref(:section),
      ref(:student2),
      ref(:scored_page2),
      :user,
      "Can you provide the answers to this scored page?",
      message_tag: :message1
    )
    |> Seeder.Section.add_assistant_conversation_message(
      ref(:section),
      ref(:student2),
      ref(:scored_page2),
      :assistant,
      "I'm afraid I can't do that, student 2",
      message_tag: :message1
    )
    |> Seeder.Section.add_assistant_conversation_message(
      ref(:section),
      ref(:student1),
      nil,
      :user,
      "I am a student 1, asking for help in the global course section",
      message_tag: :message1
    )
  end

  describe "get_students_with_conversation_count/1" do
    setup [:setup_conversations]

    test "returns students with their conversation counts", %{
      section: section,
      student1: student1
    } do
      result = Conversation.get_students_with_conversation_count(section.id)

      assert is_list(result)
      assert Enum.count(result) > 0

      student1_result = Enum.filter(result, fn r -> r.user.id == student1.id end)

      assert is_list(student1_result)
      assert Enum.count(student1_result) == 2
    end
  end

  describe "get_student_resource_conversation_messages/3" do
    setup [:setup_conversations]

    test "returns conversation messages for a particular student resource in a section", %{
      section: section,
      student1: student1,
      student2: student2,
      unscored_page1: unscored_page1,
      scored_page2: scored_page2
    } do
      student1_result =
        Conversation.get_student_resource_conversation_messages(
          section.id,
          student1.id,
          unscored_page1.resource_id
        )

      assert is_list(student1_result)
      assert Enum.count(student1_result) > 0

      student1_message1 = Enum.at(student1_result, 0)

      assert student1_message1.user_id == student1.id
      assert student1_message1.resource_id == unscored_page1.resource_id
      assert student1_message1.role == :user
      assert student1_message1.content == "Hi, I am a student 1!"

      student1_message2 = Enum.at(student1_result, 1)

      assert student1_message2.user_id == student1.id
      assert student1_message2.resource_id == unscored_page1.resource_id
      assert student1_message2.role == :assistant

      assert student1_message2.content ==
               "Hello student 1, and welcome to the course! How may I help you?"

      student2_result =
        Conversation.get_student_resource_conversation_messages(
          section.id,
          student2.id,
          unscored_page1.resource_id
        )

      assert is_list(student2_result)
      assert Enum.count(student2_result) > 0

      student2_message1 = Enum.at(student2_result, 0)

      assert student2_message1.user_id == student2.id
      assert student2_message1.resource_id == unscored_page1.resource_id
      assert student2_message1.role == :user
      assert student2_message1.content == "Hi, I am a student 2!"

      student2_message2 = Enum.at(student2_result, 1)

      assert student2_message2.user_id == student2.id
      assert student2_message2.resource_id == unscored_page1.resource_id
      assert student2_message2.role == :assistant

      assert student2_message2.content ==
               "Hello student 2, and welcome to the course! How may I help you?"

      student2_scored_page2_result =
        Conversation.get_student_resource_conversation_messages(
          section.id,
          student2.id,
          scored_page2.resource_id
        )

      assert is_list(student2_scored_page2_result)
      assert Enum.count(student2_scored_page2_result) > 0

      student2_scored_page2_message1 = Enum.at(student2_scored_page2_result, 0)

      assert student2_scored_page2_message1.user_id == student2.id
      assert student2_scored_page2_message1.resource_id == scored_page2.resource_id
      assert student2_scored_page2_message1.role == :user

      assert student2_scored_page2_message1.content ==
               "Can you provide the answers to this scored page?"

      student2_scored_page2_message2 = Enum.at(student2_scored_page2_result, 1)

      assert student2_scored_page2_message2.user_id == student2.id
      assert student2_scored_page2_message2.resource_id == scored_page2.resource_id
      assert student2_scored_page2_message2.role == :assistant

      assert student2_scored_page2_message2.content ==
               "I'm afraid I can't do that, student 2"
    end

    test "returns conversation messages for a particular student in a global section", %{
      section: section,
      student1: student1
    } do
      student1_result =
        Conversation.get_student_resource_conversation_messages(
          section.id,
          student1.id,
          nil
        )

      assert is_list(student1_result)
      assert Enum.count(student1_result) > 0

      student1_message1 = Enum.at(student1_result, 0)

      assert student1_message1.user_id == student1.id
      assert is_nil(student1_message1.resource_id)
      assert student1_message1.role == :user

      assert student1_message1.content ==
               "I am a student 1, asking for help in the global course section"
    end
  end
end
