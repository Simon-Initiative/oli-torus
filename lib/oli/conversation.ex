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
  def get_students_with_conversation_count(section_slug) do
    learner_context_role_id =
      Lti_1p3.Tool.ContextRoles.get_role(:context_learner).id

    from(u in Oli.Accounts.User,
      join: e in assoc(u, :enrollments),
      join: s in assoc(e, :section),
      join: ecr in assoc(e, :context_roles),
      join: cm in assoc(u, :assistant_conversation_messages),
      where:
        s.slug == ^section_slug and
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
  Gets all conversation messages for a student in a section.
  """
  def get_student_conversation_messages(section_slug, user_id) do
    learner_context_role_id =
      Lti_1p3.Tool.ContextRoles.get_role(:context_learner).id

    from(cm in ConversationMessage,
      join: u in assoc(cm, :user),
      join: e in assoc(u, :enrollments),
      join: s in assoc(e, :section),
      join: ecr in assoc(e, :context_roles),
      where:
        s.slug == ^section_slug and
          ecr.id == ^learner_context_role_id and
          u.id == ^user_id,
      preload: [user: u],
      order_by: [asc: u.name],
      select: cm
    )
    |> Repo.all()
  end
end
