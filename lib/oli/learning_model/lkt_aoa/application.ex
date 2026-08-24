defmodule Oli.LearningModel.LktAoa.Application do
  @moduledoc """
  Transactional application service for LKT-AOA learner state.

  The service performs validation and parameter normalization outside the write
  transaction when possible, then commits idempotency claims, evidence, and final
  learner-state mutations atomically. It deliberately uses a fixed set of bulk
  persistence boundaries instead of doing database I/O inside part/objective
  reductions.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Oli.Analytics.Summary.AttemptGroup
  alias Oli.Delivery.Sections.Section

  alias Oli.LearningModel.{
    Config,
    LearningState,
    PriorActivityPartEvidence
  }

  alias Oli.LearningModel.LktAoa.{BatchResult, Contribution, Transition}
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo
  alias Oli.Resources.Revision

  @encoded_model_version "lkt_aoa"
  @empty_counts [
    input_attempt_count: 0,
    claimed_attempt_count: 0,
    contribution_count: 0,
    affected_state_count: 0,
    new_evidence_count: 0
  ]

  @spec apply(Section.t(), AttemptGroup.t(), Config.t()) ::
          {:ok, BatchResult.t()} | {:error, term()}
  def apply(%Section{} = section, %AttemptGroup{} = group, %Config{} = config) do
    start_time = System.monotonic_time()
    input_attempt_count = length(group.part_attempts || [])

    emit_start(input_attempt_count)

    try do
      with {:ok, normalized} <- normalize(section, group) do
        normalized
        |> transaction_multi(config)
        |> Repo.transaction()
        |> case do
          {:ok, %{result: result}} ->
            emit_stop(start_time, result, nil)
            {:ok, result}

          {:error, _step, reason, _changes} ->
            emit_stop(
              start_time,
              error_result(input_attempt_count, reason),
              failure_category(reason),
              :error
            )

            {:error, reason}
        end
      else
        {:error, reason} ->
          emit_stop(
            start_time,
            error_result(input_attempt_count, reason),
            failure_category(reason),
            :error
          )

          {:error, reason}
      end
    rescue
      exception ->
        emit_exception(start_time, input_attempt_count)
        reraise exception, __STACKTRACE__
    end
  end

  defp normalize(section, group) do
    with :ok <- validate_group(section, group),
         {:ok, contributions} <- normalize_part_attempts(group),
         :ok <- Contribution.validate_consistent_evidence_mappings(contributions) do
      {:ok,
       %{
         section: section,
         group: group,
         contributions: contributions,
         input_attempt_count: length(group.part_attempts || [])
       }}
    end
  end

  defp validate_group(%Section{id: section_id}, %AttemptGroup{context: %{section_id: section_id}}),
       do: :ok

  defp validate_group(%Section{id: section_id}, %AttemptGroup{
         context: %{section_id: group_section_id}
       }),
       do: {:error, {:mixed_section_attempt_group, section_id, group_section_id}}

  defp validate_group(%Section{}, %AttemptGroup{context: context}),
    do: {:error, {:invalid_attempt_group_context, context}}

  defp normalize_part_attempts(%AttemptGroup{context: context, part_attempts: part_attempts}) do
    part_attempts
    |> Enum.reduce_while({:ok, []}, fn part_attempt, {:ok, contributions} ->
      case normalize_part_attempt(context, part_attempt) do
        {:ok, nil} -> {:cont, {:ok, contributions}}
        {:ok, contribution} -> {:cont, {:ok, [contribution | contributions]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, contributions} -> {:ok, Enum.reverse(contributions)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_part_attempt(context, part_attempt) do
    with :ok <- validate_part_attempt(part_attempt),
         {:ok, objective_ids} <-
           Contribution.objectives_for_part(part_attempt.activity_revision, part_attempt.part_id),
         {:ok, beta_part} <-
           Contribution.activity_part_beta(part_attempt.activity_revision, part_attempt.part_id) do
      case objective_ids do
        [] ->
          {:ok, nil}

        objective_ids ->
          {:ok,
           %Contribution{
             part_attempt_id: part_attempt.id,
             part_attempt_guid: part_attempt.attempt_guid,
             date_evaluated: part_attempt.date_evaluated,
             section_id: context.section_id,
             user_id: context.user_id,
             activity_id: part_attempt.activity_revision.resource_id,
             activity_revision_id: part_attempt.activity_revision.id,
             part_id: part_attempt.part_id,
             learning_objective_ids: objective_ids,
             beta_part: beta_part,
             score: part_attempt.score,
             out_of: part_attempt.out_of
           }}
      end
    end
  end

  defp validate_part_attempt(%{
         id: id,
         attempt_guid: attempt_guid,
         lifecycle_state: :evaluated,
         date_evaluated: %DateTime{},
         part_id: part_id,
         score: score,
         out_of: out_of,
         activity_revision: %Revision{id: revision_id, resource_id: activity_id}
       })
       when is_integer(id) and is_binary(attempt_guid) and attempt_guid != "" and
              is_binary(part_id) and part_id != "" and is_number(score) and is_number(out_of) and
              is_integer(revision_id) and is_integer(activity_id),
       do: :ok

  defp validate_part_attempt(%{lifecycle_state: lifecycle_state, attempt_guid: attempt_guid})
       when lifecycle_state != :evaluated,
       do: {:error, {:part_attempt_not_evaluated, attempt_guid}}

  defp validate_part_attempt(%{date_evaluated: nil, attempt_guid: attempt_guid}),
    do: {:error, {:missing_date_evaluated, attempt_guid}}

  defp validate_part_attempt(part_attempt), do: {:error, {:invalid_part_attempt, part_attempt}}

  defp transaction_multi(normalized, config) do
    Multi.new()
    |> Multi.run(:claimed_ids, fn repo, _changes ->
      claim_attempts(repo, normalized.contributions)
    end)
    |> Multi.run(:claimed_contributions, fn _repo, %{claimed_ids: claimed_ids} ->
      {:ok, filter_claimed_contributions(normalized.contributions, claimed_ids)}
    end)
    |> Multi.run(:objective_revisions, fn repo, %{claimed_contributions: contributions} ->
      resolve_objective_revisions(repo, normalized.group, contributions)
    end)
    |> Multi.run(:state_keys, fn _repo, %{claimed_contributions: contributions} ->
      {:ok, claimed_state_keys(contributions)}
    end)
    |> Multi.run(:neutral_states, fn repo, %{state_keys: state_keys} ->
      insert_neutral_states(repo, state_keys)
    end)
    |> Multi.run(:locked_states, fn repo, %{state_keys: state_keys} ->
      lock_states(repo, state_keys)
    end)
    |> Multi.run(:new_evidence_keys, fn repo, %{claimed_contributions: contributions} ->
      insert_evidence(repo, contributions)
    end)
    |> Multi.run(:final_states, fn
      _repo,
      %{
        claimed_contributions: [],
        locked_states: locked_states
      } ->
        {:ok, locked_states}

      _repo,
      %{
        claimed_contributions: contributions,
        objective_revisions: objective_revisions,
        locked_states: locked_states,
        new_evidence_keys: new_evidence_keys
      } ->
        replay(contributions, objective_revisions, locked_states, new_evidence_keys, config)
    end)
    |> Multi.run(:write_states, fn repo, %{final_states: final_states} ->
      write_final_states(repo, final_states)
    end)
    |> Multi.run(:result, fn _repo, changes ->
      {:ok, build_result(normalized.input_attempt_count, changes)}
    end)
  end

  defp claim_attempts(_repo, []), do: {:ok, []}

  defp claim_attempts(repo, contributions) do
    guids =
      contributions
      |> Enum.map(& &1.part_attempt_guid)
      |> Enum.uniq()

    now = DateTime.utc_now(:second)

    # Returned rows are the authority for all downstream mutations. PostgreSQL's
    # unique claim conflict either waits for an uncommitted competitor and returns
    # no row after commit, or succeeds after rollback; no in-memory check can
    # provide that retry/concurrency guarantee.
    sql = """
    INSERT INTO learning_model_attempt_applications (
      part_attempt_id,
      learning_model_version,
      applied_at
    )
    SELECT pa.id, $2, $3
    FROM part_attempts AS pa
    WHERE pa.attempt_guid = ANY($1)
      AND pa.lifecycle_state = 'evaluated'
    ON CONFLICT (part_attempt_id)
    DO NOTHING
    RETURNING part_attempt_id
    """

    case Ecto.Adapters.SQL.query(repo, sql, [guids, @encoded_model_version, now]) do
      {:ok, %{rows: rows}} -> {:ok, Enum.map(rows, fn [part_attempt_id] -> part_attempt_id end)}
      {:error, error} -> {:error, {:claim_failed, error}}
    end
  end

  defp filter_claimed_contributions(contributions, claimed_ids) do
    claimed_ids = MapSet.new(claimed_ids)

    contributions
    |> Enum.filter(&MapSet.member?(claimed_ids, &1.part_attempt_id))
    |> Enum.uniq_by(& &1.part_attempt_id)
  end

  defp resolve_objective_revisions(_repo, _group, []), do: {:ok, %{}}

  defp resolve_objective_revisions(repo, group, contributions) do
    objective_ids =
      contributions
      |> Enum.flat_map(& &1.learning_objective_ids)
      |> Enum.uniq()
      |> Enum.sort()

    publication_id = group.context.publication_id

    case publication_id do
      nil ->
        {:error, :missing_section_publication}

      publication_id ->
        revisions =
          from(pr in PublishedResource,
            join: revision in Revision,
            on: revision.id == pr.revision_id,
            where: pr.publication_id == ^publication_id and pr.resource_id in ^objective_ids,
            select: revision
          )
          |> repo.all()

        revision_by_resource_id = Map.new(revisions, &{&1.resource_id, &1})
        missing_ids = Enum.reject(objective_ids, &Map.has_key?(revision_by_resource_id, &1))

        case missing_ids do
          [] -> objective_betas(revision_by_resource_id)
          missing_ids -> {:error, {:missing_published_objective_revisions, missing_ids}}
        end
    end
  end

  defp objective_betas(revision_by_resource_id) do
    Enum.reduce_while(revision_by_resource_id, {:ok, %{}}, fn {objective_id, revision},
                                                              {:ok, acc} ->
      case Contribution.learning_objective_beta(revision) do
        {:ok, beta_lo} -> {:cont, {:ok, Map.put(acc, objective_id, beta_lo)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp claimed_state_keys(contributions) do
    contributions
    |> Enum.flat_map(&Contribution.state_keys/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp insert_neutral_states(_repo, []), do: {:ok, 0}

  defp insert_neutral_states(repo, state_keys) do
    now = DateTime.utc_now(:second)

    rows =
      Enum.map(state_keys, fn {section_id, user_id, learning_objective_id} ->
        %{
          section_id: section_id,
          user_id: user_id,
          learning_objective_id: learning_objective_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    # Neutral insertion before locking makes absent rows lockable. Otherwise two
    # first-opportunity transactions could both compute from zero because a
    # SELECT FOR UPDATE cannot lock a row that does not exist.
    {count, _} =
      repo.insert_all(LearningState, rows,
        on_conflict: :nothing,
        conflict_target: [:section_id, :user_id, :learning_objective_id]
      )

    {:ok, count}
  end

  defp lock_states(_repo, []), do: {:ok, %{}}

  defp lock_states(repo, state_keys) do
    {section_ids, user_ids, objective_ids} =
      Enum.reduce(state_keys, {[], [], []}, fn {section_id, user_id, objective_id},
                                               {section_ids, user_ids, objective_ids} ->
        {[section_id | section_ids], [user_id | user_ids], [objective_id | objective_ids]}
      end)

    sql = """
    SELECT
      state.section_id,
      state.user_id,
      state.learning_objective_id,
      state.attempt_count,
      state.success_score,
      state.failure_score,
      state.recency_logit,
      state.aoa,
      state.unique_activity_part_count,
      state.confidence,
      state.inserted_at,
      state.updated_at
    FROM learning_states AS state
    JOIN unnest($1::bigint[], $2::bigint[], $3::bigint[])
      AS key(section_id, user_id, learning_objective_id)
      ON state.section_id = key.section_id
     AND state.user_id = key.user_id
     AND state.learning_objective_id = key.learning_objective_id
    ORDER BY state.section_id, state.user_id, state.learning_objective_id
    FOR UPDATE
    """

    case Ecto.Adapters.SQL.query(repo, sql, [
           Enum.reverse(section_ids),
           Enum.reverse(user_ids),
           Enum.reverse(objective_ids)
         ]) do
      {:ok, %{rows: rows}} ->
        state_map =
          rows
          |> Enum.map(&learning_state_from_row/1)
          |> Map.new(&{{&1.section_id, &1.user_id, &1.learning_objective_id}, &1})

        case Enum.reject(state_keys, &Map.has_key?(state_map, &1)) do
          [] -> {:ok, state_map}
          missing_keys -> {:error, {:missing_learning_states_after_initialization, missing_keys}}
        end

      {:error, error} ->
        {:error, {:state_lock_failed, error}}
    end
  end

  defp insert_evidence(_repo, []), do: {:ok, []}

  defp insert_evidence(repo, contributions) do
    now = DateTime.utc_now(:second)

    rows =
      contributions
      |> Enum.map(&Contribution.evidence_key/1)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(fn {section_id, user_id, activity_id, part_id} ->
        %{
          section_id: section_id,
          user_id: user_id,
          activity_id: activity_id,
          part_id: part_id,
          inserted_at: now
        }
      end)

    # Evidence rows are activity-part facts, not per-objective facts. Only rows
    # returned by this conflict-tolerant insert can fan out into confidence
    # increments, so repeated encounters update proficiency but not breadth.
    {_count, returned} =
      repo.insert_all(PriorActivityPartEvidence, rows,
        on_conflict: :nothing,
        conflict_target: [:section_id, :user_id, :activity_id, :part_id],
        returning: [:section_id, :user_id, :activity_id, :part_id]
      )

    {:ok,
     Enum.map(returned, fn evidence ->
       {evidence.section_id, evidence.user_id, evidence.activity_id, evidence.part_id}
     end)}
  rescue
    error -> {:error, {:evidence_insert_failed, error}}
  end

  defp replay(contributions, objective_revisions, locked_states, new_evidence_keys, config) do
    replay_contributions =
      Enum.flat_map(contributions, fn contribution ->
        Enum.map(contribution.learning_objective_ids, fn objective_id ->
          %{
            state_key: {contribution.section_id, contribution.user_id, objective_id},
            part_attempt_guid: contribution.part_attempt_guid,
            date_evaluated: contribution.date_evaluated,
            beta_lo: Map.fetch!(objective_revisions, objective_id),
            beta_part: contribution.beta_part,
            correct: Contribution.binary_outcome(contribution)
          }
        end)
      end)

    confidence_increments =
      Contribution.confidence_increments_for_new_evidence(contributions, new_evidence_keys)

    Transition.replay_by_state(locked_states, replay_contributions, confidence_increments, config)
  end

  defp write_final_states(_repo, states) when map_size(states) == 0, do: {:ok, 0}

  defp write_final_states(repo, states) do
    now = DateTime.utc_now(:second)

    rows =
      states
      |> Map.values()
      |> Enum.map(fn state ->
        %{
          section_id: state.section_id,
          user_id: state.user_id,
          learning_objective_id: state.learning_objective_id,
          attempt_count: state.attempt_count,
          success_score: state.success_score,
          failure_score: state.failure_score,
          recency_logit: state.recency_logit,
          aoa: state.aoa,
          unique_activity_part_count: state.unique_activity_part_count,
          confidence: state.confidence,
          inserted_at: state.inserted_at || now,
          updated_at: now
        }
      end)

    # One final write per affected-state set replaces only derived mutable state.
    # No external I/O belongs between the ordered lock and this write because the
    # transaction is intentionally short and controls learner-state serialization.
    {count, _} =
      repo.insert_all(LearningState, rows,
        on_conflict:
          {:replace,
           [
             :attempt_count,
             :success_score,
             :failure_score,
             :recency_logit,
             :aoa,
             :unique_activity_part_count,
             :confidence,
             :updated_at
           ]},
        conflict_target: [:section_id, :user_id, :learning_objective_id]
      )

    {:ok, count}
  rescue
    error -> {:error, {:state_write_failed, error}}
  end

  defp learning_state_from_row([
         section_id,
         user_id,
         learning_objective_id,
         attempt_count,
         success_score,
         failure_score,
         recency_logit,
         aoa,
         unique_activity_part_count,
         confidence,
         inserted_at,
         updated_at
       ]) do
    %LearningState{
      section_id: section_id,
      user_id: user_id,
      learning_objective_id: learning_objective_id,
      attempt_count: attempt_count,
      success_score: success_score,
      failure_score: failure_score,
      recency_logit: recency_logit,
      aoa: aoa,
      unique_activity_part_count: unique_activity_part_count,
      confidence: confidence,
      inserted_at: utc_datetime(inserted_at),
      updated_at: utc_datetime(updated_at)
    }
  end

  defp utc_datetime(%DateTime{} = datetime), do: datetime

  # PostgreSQL returns timestamp columns from the raw lock query as NaiveDateTime.
  # The schema fields are utc_datetime, so normalize at the SQL boundary before
  # the state is reused in insert_all.
  defp utc_datetime(%NaiveDateTime{} = datetime), do: DateTime.from_naive!(datetime, "Etc/UTC")

  defp build_result(input_attempt_count, changes) do
    claimed = Map.get(changes, :claimed_contributions, [])
    affected_states = Map.get(changes, :state_keys, [])
    new_evidence_keys = Map.get(changes, :new_evidence_keys, [])

    status =
      case claimed do
        [] -> :noop
        _ -> :applied
      end

    BatchResult.new(
      status,
      Keyword.merge(@empty_counts,
        input_attempt_count: input_attempt_count,
        claimed_attempt_count: length(Map.get(changes, :claimed_ids, [])),
        contribution_count:
          claimed
          |> Enum.flat_map(& &1.learning_objective_ids)
          |> length(),
        affected_state_count: length(affected_states),
        new_evidence_count: length(new_evidence_keys)
      )
    )
  end

  @telemetry_prefix [:oli, :learning_model, :lkt_aoa, :batch]

  # Telemetry metadata for this hot path is intentionally aggregate-only. Do not
  # include Section/user/resource IDs, PartAttempt IDs/GUIDs, part IDs, scores,
  # responses, SQL binds, exception structs, or parameter payloads here.
  defp emit_start(input_attempt_count) do
    :telemetry.execute(
      @telemetry_prefix ++ [:start],
      %{system_time: System.system_time()},
      %{model: :lkt_aoa, input_attempt_count: input_attempt_count}
    )
  end

  defp emit_stop(start_time, %BatchResult{} = result, failure_category, result_override \\ nil) do
    :telemetry.execute(
      @telemetry_prefix ++ [:stop],
      %{duration: System.monotonic_time() - start_time},
      telemetry_metadata(result, failure_category, result_override)
    )
  end

  defp emit_exception(start_time, input_attempt_count) do
    :telemetry.execute(
      @telemetry_prefix ++ [:exception],
      %{duration: System.monotonic_time() - start_time},
      %{
        model: :lkt_aoa,
        result: :exception,
        failure_category: :exception,
        input_attempt_count: input_attempt_count
      }
    )
  end

  defp telemetry_metadata(%BatchResult{} = result, failure_category, result_override) do
    %{
      model: :lkt_aoa,
      result: result_override || result.status,
      failure_category: failure_category,
      input_attempt_count: result.input_attempt_count,
      claimed_attempt_count: result.claimed_attempt_count,
      contribution_count: result.contribution_count,
      affected_state_count: result.affected_state_count,
      new_evidence_count: result.new_evidence_count
    }
  end

  defp error_result(input_attempt_count, _reason) do
    BatchResult.new(:noop, Keyword.put(@empty_counts, :input_attempt_count, input_attempt_count))
  end

  defp failure_category({:part_attempt_not_evaluated, _}), do: :invalid_input
  defp failure_category({:missing_date_evaluated, _}), do: :invalid_input
  defp failure_category({:invalid_part_attempt, _}), do: :invalid_input
  defp failure_category({:invalid_part_id, _}), do: :invalid_input
  defp failure_category({:invalid_objective_id, _}), do: :invalid_input
  defp failure_category({:invalid_objective_mapping, _}), do: :invalid_input
  defp failure_category({:conflicting_objective_mapping, _, _, _}), do: :invalid_input
  defp failure_category({:mixed_section_attempt_group, _, _}), do: :invalid_input
  defp failure_category({:invalid_attempt_group_context, _}), do: :invalid_input
  defp failure_category(:missing_section_publication), do: :publication
  defp failure_category({:missing_published_objective_revisions, _}), do: :publication
  defp failure_category({:invalid_activity_part_parameters, _, _}), do: :parameter
  defp failure_category({:invalid_activity_parameters, _}), do: :parameter
  defp failure_category({:invalid_learning_objective_parameters, _}), do: :parameter
  defp failure_category({:invalid_revision_resource_type, _, _}), do: :parameter
  defp failure_category({:claim_failed, _}), do: :claim
  defp failure_category({:state_lock_failed, _}), do: :state_lock
  defp failure_category({:missing_learning_states_after_initialization, _}), do: :state_lock

  defp failure_category(
         {:evidence_insert_failed, %Postgrex.Error{postgres: %{code: :deadlock_detected}}}
       ),
       do: :deadlock

  defp failure_category(
         {:state_write_failed, %Postgrex.Error{postgres: %{code: :deadlock_detected}}}
       ),
       do: :deadlock

  defp failure_category(
         {:evidence_insert_failed, %Postgrex.Error{postgres: %{code: :check_violation}}}
       ),
       do: :constraint

  defp failure_category(
         {:state_write_failed, %Postgrex.Error{postgres: %{code: :check_violation}}}
       ),
       do: :constraint

  defp failure_category({:evidence_insert_failed, _}), do: :evidence
  defp failure_category({:state_write_failed, _}), do: :state_write
  defp failure_category(_reason), do: :unknown
end
