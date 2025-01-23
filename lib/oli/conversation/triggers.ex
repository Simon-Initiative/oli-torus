defmodule Oli.Conversation.Triggers  do

  import Ecto.Query
  alias Oli.Repo

  alias Phoenix.PubSub

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

  def description(:visit_page, _), do: "Visited the learning page"
  def description(:content_group, id), do: "Clicked a button next to a content group id (id: #{id})"
  def description(:content_block, id), do: "Viewed a content block (id: #{id})"
  def description(:correct_answer, data), do: "Answered correctly question: #{data.question}"
  def description(:incorrect_answer, data), do: "Answered incorrectly question: #{data.question}"
  def description(:hint_request, data), do: "Requested a hint (id: #{data.id}) from question: #{data.question}"
  def description(:explanation, data), do: "Received the explanation (id: #{data.id}) from question: #{data.question}"
  def description(:targeted_feedback, data), do: "Received targeted feedback (id: #{data.id}) from question: #{data.question}"

  @doc """
  Verify that the user is enrolled in a section with
  with the AI agent enabled.
  """
  def verify_access(section_slug, user_id) do

   case Oli.Accounts.User
      |> join(:left, [u], e in Oli.Delivery.Sections.Enrollment, on: u.id == e.user_id)
      |> join(:left, [_, e], s in Oli.Delivery.Sections.Section, on: s.id == e.section_id)
      |> where([_, e, s], s.slug == ^section_slug and s.assistant_enabled == true and e.user_id == ^user_id)
      |> select([_, _, s], s)
      |> limit(1)
      |> Repo.one() do

      nil -> {:error, :no_access}

      section -> {:ok, section}

    end

  end

  def invoke(section, current_user, trigger) do

    topic = "trigger:#{current_user.id}:#{section.id}:#{trigger.resource_id}"

    IO.inspect(topic)

    PubSub.broadcast(
      Oli.PubSub,
      topic,
      {:trigger, trigger}
    )

  end

end
