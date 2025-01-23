defmodule Oli.Conversation.Triggers  do

  import Ecto.Query
  alias Oli.Repo

  @trigger_types [
    :visit_page,
    :content_group,
    :content_block,
    :correct_answer,
    :incorrect_answer,
    :hint_request,
    :explanation,
    :targeted_feedback
  ]

  @doc """
  Verify that the user is enrolled in a section with
  with the AI agent enabled.
  """
  def verify_access(section_slug, user_id) do

   case
      Oli.Accounts.User
      |> join(:left, [u], e in Oli.Delivery.Sections.Enrollment, on: u.id == e.user_id)
      |> join(:left, [_, e], s in Oli.Delivery.Sections.Section, on: s.id == e.section_id)
      |> where([_, _, s], s.slug == ^section_slug and s.assistant_enabled == true)
      |> select([_, _, s], s)
      |> limit(1)
      |> Repo.one() do

      nil -> {:error, :no_access}

      section -> {:ok, section}

    end

  end

  def invoke(section, current_user, trigger) do



  end

end
