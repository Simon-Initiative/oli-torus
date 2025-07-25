defmodule Oli.Conversation do
  @moduledoc """
  Support for dialogues (chatlike conversations) between human users
  and generative AI agents.
  """

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Conversation.ConversationMessage

  @doc """
  Gets all students enrolled in a section and their conversation counts.
  """
  def get_students_with_conversation_count(section_id) do
    learner_context_role_id =
      Lti_1p3.Roles.ContextRoles.get_role(:context_learner).id

    from(u in Oli.Accounts.User,
      join: e in assoc(u, :enrollments),
      join: ecr in assoc(e, :context_roles),
      join: cm in assoc(u, :assistant_conversation_messages),
      where:
        cm.section_id == ^section_id and
          cm.role in ^["user", "assistant", "function"] and
          ecr.id == ^learner_context_role_id,
      order_by: [asc: u.name],
      group_by: [u.id, cm.section_id, cm.resource_id, cm.user_id],
      select: %{
        user: u,
        resource_id: cm.resource_id,
        num_messages: count(cm.user_id)
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets all conversation messages for a particular student resource in a section.
  """
  def get_student_resource_conversation_messages(section_id, user_id, nil) do
    from(cm in ConversationMessage,
      where:
        cm.section_id == ^section_id and
          cm.role in ^["user", "assistant", "function"] and
          cm.user_id == ^user_id and
          is_nil(cm.resource_id),
      order_by: [asc: cm.inserted_at],
      select: cm
    )
    |> Repo.all()
  end

  def get_student_resource_conversation_messages(section_id, user_id, resource_id) do
    from(cm in ConversationMessage,
      where:
        cm.section_id == ^section_id and
          cm.role in ^["user", "assistant", "function"] and
          cm.user_id == ^user_id and
          cm.resource_id == ^resource_id,
      order_by: [asc: cm.inserted_at],
      select: cm
    )
    |> Repo.all()
  end

  @doc """
  Persist a new conversation message.
  """
  def create_conversation_message(message, user_id, resource_id, section_id) do
    attrs =
      message
      |> Map.from_struct()
      |> Map.merge(%{user_id: user_id, resource_id: resource_id, section_id: section_id})

    %ConversationMessage{}
    |> ConversationMessage.changeset(attrs)
    |> Repo.insert()
  end
end
