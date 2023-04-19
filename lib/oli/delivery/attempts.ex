defmodule Oli.Delivery.Attempts do
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, ActivityAttempt, ResourceAccess, PartAttempt}
  alias Oli.Resources.Revision

  alias Oli.Repo
  import Ecto.Query, warn: false

  def summarize_survey(survey_resource_id, user_id) do
    mcq_reg = Oli.Activities.get_registration_by_slug("oli_multiple_choice")

    ActivityAttempt
    |> join(:inner, [a_att], r_att in ResourceAttempt, on: a_att.resource_attempt_id == r_att.id)
    |> join(:inner, [a_att, r_att], r_acc in ResourceAccess,
      on: r_att.resource_access_id == r_acc.id
    )
    |> join(:inner, [a_att, r_att, r_acc], rev in Revision, on: a_att.revision_id == rev.id)
    |> join(:left, [a_att], a_att_2 in ActivityAttempt,
      on:
        a_att.resource_attempt_id == a_att_2.resource_attempt_id and
          a_att.resource_id == a_att_2.resource_id and a_att.id < a_att_2.id and
          a_att_2.lifecycle_state == :evaluated
    )
    |> join(:inner, [a_att], p_att in PartAttempt, on: p_att.activity_attempt_id == a_att.id)
    |> where(
      [a_att, r_att, r_acc, rev, a_att_2],
      r_acc.resource_id == ^survey_resource_id and r_acc.user_id == ^user_id and is_nil(a_att_2) and
        a_att.lifecycle_state == :evaluated and rev.activity_type_id == ^mcq_reg.id
    )
    |> select([a_att, r_att, r_acc, rev, a_att_2, p_att], %{
      question: rev.title,
      options: a_att.transformed_model["choices"],
      answer: p_att.response
    })
    |> Repo.all()
    |> Enum.map(fn %{question: question, options: options, answer: answer} ->
      %{
        title: question,
        response:
          options
          |> Enum.find(%{}, &(&1["id"] == answer["input"]))
          |> Map.get("content", %{})
          |> Enum.at(0, %{})
          |> Map.get("children", %{})
          |> Enum.at(0, %{})
          |> Map.get("text", %{})
      }
    end)
  end
end
