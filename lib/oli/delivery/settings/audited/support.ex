defmodule Oli.Delivery.Settings.Audited.Support do
  @moduledoc false
  # Event recording, actor loading, and the assessment settings policy shared by the private
  # modules of `Oli.Delivery.Settings.Audited`.

  alias Oli.Accounts.{Author, User}
  alias Oli.Auditing
  alias Oli.Auditing.Context
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Repo

  # `late_policy` is a pseudo key expanded into `late_start` and `late_submit`; the events
  # record the persisted fields.
  @assessment_policy Map.delete(Fields.assessment_settings(), :late_policy)
  @exception_policy Map.delete(Fields.student_exception(), :late_policy)

  @doc "The fields `assessment_settings_changed` records."
  def assessment_policy, do: @assessment_policy

  @doc "The fields the student exception events record."
  def exception_policy, do: @exception_policy

  @doc """
  Builds an event from each of `proposals` and inserts them in one statement in the current
  transaction. Proposals of events that record nothing without changes and have none are left
  out.
  """
  def record_many(%Context{} = context, proposals) do
    proposals
    |> Enum.reduce_while({:ok, []}, fn proposal, {:ok, changesets} ->
      case Auditing.build(context, proposal) do
        {:ok, changeset} -> {:cont, {:ok, [changeset | changesets]}}
        {:error, :no_changes} -> {:cont, {:ok, changesets}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, changesets} -> changesets |> Enum.reverse() |> Auditing.insert_all()
      error -> error
    end
  end

  @doc """
  Loads the account `context` names, for the checks that need it (secure delivery requires a
  settings editor of the section).
  """
  def actor(%Context{actor_type: :user, user_id: id}) when is_integer(id), do: fetch(User, id)

  def actor(%Context{actor_type: :author, author_id: id}) when is_integer(id),
    do: fetch(Author, id)

  def actor(_context), do: {:error, :invalid_request}

  defp fetch(schema, id) do
    case Repo.get(schema, id) do
      nil -> {:error, :invalid_request}
      account -> {:ok, account}
    end
  end
end
