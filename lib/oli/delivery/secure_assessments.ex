defmodule Oli.Delivery.SecureAssessments do
  @moduledoc """
  Session-local secure assessment authorization. This context never discovers other
  sessions belonging to a learner. Admission is wired separately.

  These checks supplement, rather than replace, enrollment, review/feedback and
  normal role authorization. Callers must authorize the complete input set before
  performing any sensitive read or mutation.
  """

  import Ecto.Query

  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Sections.{Section, SectionResource}
  alias Oli.Delivery.SecureAssessments.{Admission, Scope, Target}
  alias Oli.Repo
  alias Oli.Resources.Revision

  @operations [
    :prologue,
    :deliver,
    :start,
    :save,
    :submit,
    :review,
    :dependency_read,
    :dependency_write
  ]

  @doc "Returns the runtime instance capability, disabled by default."
  @spec supported?() :: boolean()
  def supported?, do: Application.get_env(:oli, :supports_secure_delivery, false) == true

  @doc """
  Rechecks verified entry against current policy and enrollment. Must run inside the
  issuance transaction: the selected resource row stays locked through token insert.
  Only the assessment row is locked; no learner or other-session lock is taken.
  """
  @spec admit(%Oli.Accounts.User{}, Admission.t()) :: {:ok, Scope.t()} | {:error, atom()}
  def admit(user, admission) do
    case Repo.in_transaction?() do
      true -> admit_in_transaction(user, admission)
      false -> {:error, :admission_transaction_required}
    end
  end

  defp admit_in_transaction(%{id: user_id}, %Admission{
         user_id: user_id,
         section_id: section_id,
         resource_id: resource_id
       })
       when is_integer(section_id) and section_id > 0 and is_integer(resource_id) and
              resource_id > 0 do
    page_type = Oli.Resources.ResourceType.id_for_page()

    resource =
      Repo.one(
        from sr in SectionResource,
          where: sr.section_id == ^section_id and sr.resource_id == ^resource_id,
          lock: "FOR UPDATE"
      )

    cond do
      not supported?() ->
        {:error, :secure_delivery_unsupported}

      not match?(%{secure_delivery: true, graded: true, resource_type_id: ^page_type}, resource) ->
        {:error, :secure_target_invalid}

      not Repo.exists?(
        from e in Oli.Delivery.Sections.Enrollment,
          join: s in Section,
          on: s.id == e.section_id,
          where:
            e.user_id == ^user_id and e.section_id == ^section_id and
              e.status == :enrolled and s.status == :active
      ) ->
        {:error, :not_enrolled}

      true ->
        {:ok, %Scope{section_id: section_id, resource_id: resource_id}}
    end
  end

  defp admit_in_transaction(_, _), do: {:error, :secure_target_invalid}

  @doc "Atomically rechecks generic admission and inserts one independently scoped session token."
  @spec issue_session(%Oli.Accounts.User{}, Admission.t()) :: {:ok, binary()} | {:error, term()}
  def issue_session(user, %Admission{} = admission) do
    Repo.transaction(fn ->
      with {:ok, scope} <- admit(user, admission),
           {token, record} <- Oli.Accounts.UserToken.build_session_token(user, scope),
           {:ok, _} <-
             record
             |> Ecto.Changeset.change()
             |> Ecto.Changeset.foreign_key_constraint(:user_id)
             |> Ecto.Changeset.foreign_key_constraint(:secure_section_id)
             |> Ecto.Changeset.foreign_key_constraint(:secure_resource_id)
             |> Repo.insert() do
        token
      else
        {:error, %Ecto.Changeset{}} -> Repo.rollback(:secure_session_persistence_failed)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc "Resolves a section page without constructing delivery context or recording a visit."
  def resolve_page(section_slug, revision_slug)
      when is_binary(section_slug) and is_binary(revision_slug) do
    query =
      from sr in SectionResource,
        join: s in Section,
        on: s.id == sr.section_id,
        join: r in Revision,
        on: r.resource_id == sr.resource_id,
        where: s.slug == ^section_slug and r.slug == ^revision_slug,
        select: %Target{
          section_id: s.id,
          resource_id: sr.resource_id,
          secure_delivery: sr.secure_delivery,
          revision_id: r.id
        }

    case Repo.one(query) do
      nil -> {:error, :not_found}
      target -> {:ok, target}
    end
  end

  def resolve_page(_, _), do: {:error, :not_found}

  @doc "Finds protected page dependencies from the authoritative section projection, in one query."
  def protected_models?(section_slug, resource_ids) when is_list(resource_ids) do
    attempt_membership =
      from aa in ActivityAttempt,
        join: ra in ResourceAttempt,
        on: ra.id == aa.resource_attempt_id,
        join: access in ResourceAccess,
        on: access.id == ra.resource_access_id,
        where: access.section_id == parent_as(:page).section_id,
        where: access.resource_id == parent_as(:page).resource_id,
        where: aa.resource_id in ^resource_ids,
        select: 1

    Repo.exists?(
      from sr in SectionResource,
        as: :page,
        join: s in Section,
        on: s.id == sr.section_id,
        where: s.slug == ^section_slug and sr.secure_delivery,
        where:
          fragment("? && ?::bigint[]", sr.related_activities, ^resource_ids) or
            sr.resource_id in ^resource_ids or exists(subquery(attempt_membership))
    )
  end

  @doc """
  Resolves an entire bounded attempt batch in one joined query. The returned page
  revision is the attempt's pinned revision. Missing members fail the whole batch.
  Mutation batches reject duplicate identifiers before querying.
  """
  def resolve_attempts(kind, guids, mutation? \\ false)

  def resolve_attempts(kind, guids, mutation?)
      when kind in [:resource, :activity, :part] and is_list(guids) do
    limit = if mutation?, do: 1000, else: 100

    cond do
      length(guids) > limit ->
        {:error, :invalid_batch}

      Enum.any?(guids, &(not is_binary(&1) or byte_size(&1) > 255 or &1 == "")) ->
        {:error, :invalid_batch}

      mutation? and length(Enum.uniq(guids)) != length(guids) ->
        {:error, :invalid_batch}

      guids == [] ->
        {:ok, []}

      true ->
        unique = Enum.uniq(guids)
        targets = Repo.all(attempt_query(kind, unique))

        case length(targets) == length(unique) do
          true -> {:ok, targets}
          false -> {:error, :not_found}
        end
    end
  end

  def resolve_attempts(_, _, _), do: {:error, :invalid_batch}

  defp attempt_query(kind, guids) do
    base =
      from ra in ResourceAttempt,
        as: :attempt,
        join: access in ResourceAccess,
        as: :access,
        on: access.id == ra.resource_access_id,
        join: sr in SectionResource,
        on: sr.section_id == access.section_id and sr.resource_id == access.resource_id,
        select: %Target{
          section_id: access.section_id,
          resource_id: access.resource_id,
          secure_delivery: sr.secure_delivery,
          user_id: access.user_id,
          revision_id: ra.revision_id,
          resource_attempt_guid: ra.attempt_guid,
          lifecycle_state: ra.lifecycle_state
        }

    case kind do
      :resource ->
        from [attempt: ra] in base, where: ra.attempt_guid in ^guids

      :activity ->
        from [attempt: ra] in base,
          join: aa in ActivityAttempt,
          on: aa.resource_attempt_id == ra.id,
          where: aa.attempt_guid in ^guids,
          select_merge: %{
            activity_attempt_guid: aa.attempt_guid,
            activity_resource_id: aa.resource_id,
            activity_revision_id: aa.revision_id
          }

      :part ->
        from [attempt: ra] in base,
          join: aa in ActivityAttempt,
          on: aa.resource_attempt_id == ra.id,
          join: pa in PartAttempt,
          on: pa.activity_attempt_id == aa.id,
          where: pa.attempt_guid in ^guids,
          select_merge: %{
            activity_attempt_guid: aa.attempt_guid,
            activity_resource_id: aa.resource_id,
            activity_revision_id: aa.revision_id,
            part_attempt_guid: pa.attempt_guid
          }
    end
  end

  @doc "Checks current-token confinement independently of the resource's current policy."
  def authorize_session_scope(nil, operation, %Target{}) when operation in @operations, do: :ok

  def authorize_session_scope(%Scope{section_id: s, resource_id: r}, operation, %Target{
        section_id: s,
        resource_id: r
      })
      when operation in @operations, do: :ok

  def authorize_session_scope(_, _, _), do: {:error, :secure_resource_mismatch}

  @doc """
  Enforces owner and current resource policy. Finalized ordinary review is only a
  preliminary authorization: the caller must still apply ReviewPolicy and feedback
  filtering. Neither instance disablement nor resource toggles remove token scope.
  """
  def authorize(nil, _user_id, :review, %Target{secure_delivery: false}), do: {:ok, :review}

  def authorize(scope, user_id, operation, %Target{} = target) when operation in @operations do
    with :ok <- authorize_session_scope(scope, operation, target),
         :ok <- owner(target, user_id) do
      cond do
        operation == :review and target.lifecycle_state not in [:submitted, :evaluated] ->
          {:error, :review_not_allowed}

        operation == :review ->
          {:ok, :review}

        target.secure_delivery and is_nil(scope) ->
          {:error, :secure_launch_required}

        (not is_nil(scope) or target.secure_delivery) and
          target.lifecycle_state in [:submitted, :evaluated] and
            operation in [:start, :save, :submit, :dependency_read, :dependency_write] ->
          {:error, :review_not_allowed}

        not is_nil(scope) ->
          {:ok, :secure_delivery}

        true ->
          {:ok, :ordinary_delivery}
      end
    end
  end

  def authorize(_, _, _, _), do: {:error, :secure_resource_mismatch}

  defp owner(%Target{user_id: nil}, _), do: :ok
  defp owner(%Target{user_id: id}, id) when is_integer(id), do: :ok
  defp owner(_, _), do: {:error, :not_found}

  @doc "Checks all canonical targets and supplied parent constraints before any work is performed."
  def authorize_batch(scope, user_id, operation, targets, parents \\ %{}) do
    result =
      Enum.reduce_while(targets, :ok, fn target, :ok ->
        case Enum.all?(parents, fn {key, value} -> Map.get(target, key) == value end) do
          false ->
            {:halt, {:error, :not_found}}

          true ->
            case authorize(scope, user_id, operation, target) do
              {:ok, _} -> {:cont, :ok}
              error -> {:halt, error}
            end
        end
      end)

    with :ok <- result do
      review_targets =
        Enum.filter(targets, fn t ->
          operation == :review and
            t.lifecycle_state in [:submitted, :evaluated] and
            (not is_nil(scope) or t.secure_delivery)
        end)

      case review_settings(review_targets) do
        {:ok, _} -> :ok
        error -> error
      end
    end
  end

  @doc "Resolves models only through actual activity membership in a pinned parent attempt."
  def resolve_models(guid, ids) when is_binary(guid) and is_list(ids) and length(ids) <= 100 do
    with {:ok, [target]} <- resolve_attempts(:resource, [guid]) do
      attempts =
        Repo.all(
          from a in ActivityAttempt,
            join: r in ResourceAttempt,
            on: r.id == a.resource_attempt_id,
            where: r.attempt_guid == ^guid and a.resource_id in ^ids,
            distinct: a.resource_id,
            order_by: [asc: a.resource_id, desc: a.attempt_number],
            preload: [:revision]
        )

      case MapSet.new(Enum.map(attempts, & &1.resource_id)) == MapSet.new(ids) do
        true -> {:ok, target, attempts}
        false -> {:error, :not_found}
      end
    end
  end

  def resolve_models(_, _), do: {:error, :invalid_batch}

  @doc "Loads effective pinned review settings in bounded sets, before delivery context or dependency work."
  def review_settings([]), do: {:ok, %{}}

  def review_settings(targets) do
    revision_ids = Enum.map(targets, & &1.revision_id) |> Enum.uniq()
    section_ids = Enum.map(targets, & &1.section_id) |> Enum.uniq()
    resource_ids = Enum.map(targets, & &1.resource_id) |> Enum.uniq()
    user_ids = Enum.map(targets, & &1.user_id) |> Enum.uniq()

    revisions =
      Repo.all(from r in Revision, where: r.id in ^revision_ids) |> Map.new(&{&1.id, &1})

    resources =
      Repo.all(
        from sr in SectionResource,
          where: sr.section_id in ^section_ids and sr.resource_id in ^resource_ids
      )
      |> Map.new(&{{&1.section_id, &1.resource_id}, &1})

    exceptions =
      Repo.all(
        from e in Oli.Delivery.Settings.StudentException,
          where:
            e.section_id in ^section_ids and e.resource_id in ^resource_ids and
              e.user_id in ^user_ids
      )
      |> Map.new(&{{&1.section_id, &1.resource_id, &1.user_id}, &1})

    targets
    |> Enum.uniq_by(& &1.resource_attempt_guid)
    |> Enum.reduce_while({:ok, %{}}, fn t, {:ok, acc} ->
      with %Revision{} = revision <- revisions[t.revision_id],
           %SectionResource{} = resource <- resources[{t.section_id, t.resource_id}],
           settings <-
             Oli.Delivery.Settings.combine(
               revision,
               resource,
               exceptions[{t.section_id, t.resource_id, t.user_id}]
             ),
           true <- Oli.Delivery.Attempts.ReviewPolicy.review_submission_allowed?(settings) do
        {:cont, {:ok, Map.put(acc, t.resource_attempt_guid, settings)}}
      else
        _ -> {:halt, {:error, :review_not_allowed}}
      end
    end)
  end
end
