defmodule Oli.InstructorDashboard.Recommendations do
  @moduledoc """
  Lifecycle boundary for instructor-dashboard recommendation generation.
  """

  import Ecto.Query, warn: false
  require Logger

  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Dashboard.Cache
  alias Oli.Dashboard.Cache.Key
  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Scope
  alias Oli.Delivery.Sections
  alias Oli.GenAI.Execution
  alias Oli.GenAI.FeatureConfig
  alias Oli.InstructorDashboard.DataSnapshot
  alias Oli.InstructorDashboard.Oracles.Helpers
  alias Oli.Slack
  alias OliWeb.Common.Utils, as: CommonUtils

  alias Oli.InstructorDashboard.Recommendations.{
    Builder,
    FeedbackSlack,
    LiveSync,
    Payload,
    Prompt,
    RecommendationFeedback,
    RecommendationInstance,
    Telemetry
  }

  alias Oli.Dashboard.RevisitCache
  alias Oli.Repo

  @feature :instructor_dashboard_recommendation
  @oracle_key :oracle_instructor_recommendation
  @cache_key_meta %{oracle_version: 1, data_version: 1}
  @implicit_window_hours 24
  # Treat a generating row as live long enough to cover normal provider latency,
  # but short enough that abandoned work does not block a fresh retry for long.
  @generation_lease_seconds 120
  @no_signal_message "There is no specific recommendation at this point in time, as there isn't enough student data."
  @fallback_message "There is no specific recommendation at this point in time."
  @summary_consumers [:progress_summary, :support_summary, :assessments_summary]

  @doc """
  Returns the latest recommendation payload for the given dashboard context.

  In implicit mode this reuses the latest persisted recommendation within the
  reuse window when available, deduplicates against active `:generating` rows,
  and only invokes the provider when a fresh recommendation is needed.
  """
  @spec get_recommendation(OracleContext.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_recommendation(%OracleContext{} = context, opts \\ []) do
    started_at_ms = System.monotonic_time(:millisecond)
    mode = Keyword.get(opts, :mode, :implicit)
    now = Keyword.get(opts, :now, DateTime.utc_now())

    with {:ok, section_id, scope} <- Helpers.section_scope(context) do
      case active_or_expired_generation(section_id, scope, now) do
        {:ok, %RecommendationInstance{} = generation} ->
          {:ok, normalize_instance(generation, context.user_id)}

        {:expired, _expired_generation} ->
          continue_recommendation_lookup(
            context,
            section_id,
            scope,
            mode,
            latest_instance(section_id, scope),
            started_at_ms,
            opts,
            now
          )

        :none ->
          continue_recommendation_lookup(
            context,
            section_id,
            scope,
            mode,
            latest_instance(section_id, scope),
            started_at_ms,
            opts,
            now
          )
      end
    else
      {:error, reason} = error ->
        emit_lifecycle_telemetry(started_at_ms, context, context.scope, %{
          action: normalize_action(mode),
          outcome: :error,
          error_type: error_reason_type(reason)
        })

        error
    end
  end

  defp continue_recommendation_lookup(
         context,
         section_id,
         scope,
         mode,
         latest_instance,
         started_at_ms,
         opts,
         now
       ) do
    case {mode, latest_instance} do
      {:implicit, %RecommendationInstance{} = instance} ->
        if within_implicit_window?(instance, now) do
          payload = normalize_instance(instance, context.user_id)
          cache_refresh = maybe_refresh_cache(context, scope, payload, opts)

          emit_lifecycle_telemetry(started_at_ms, context, scope, %{
            action: :implicit_read,
            outcome: :reused,
            rate_limit: :hit,
            cache_refresh: cache_refresh
          })

          {:ok, payload}
        else
          generate_recommendation(context, scope, section_id, :implicit, started_at_ms, opts)
        end

      {:implicit, _} ->
        generate_recommendation(context, scope, section_id, :implicit, started_at_ms, opts)

      {:explicit_regen, _} ->
        generate_recommendation(
          context,
          scope,
          section_id,
          :explicit_regen,
          started_at_ms,
          opts
        )

      _ ->
        emit_lifecycle_telemetry(started_at_ms, context, scope, %{
          action: normalize_action(mode),
          outcome: :error,
          error_type: :unsupported_mode
        })

        {:error, {:unsupported_mode, mode}}
    end
  end

  @doc """
  Forces a fresh recommendation generation for the current dashboard scope.

  This bypasses the implicit daily reuse window and refreshes the latest visible
  recommendation for the scope.
  """
  @spec regenerate_recommendation(OracleContext.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def regenerate_recommendation(%OracleContext{} = context, opts \\ []) do
    get_recommendation(context, Keyword.put(opts, :mode, :explicit_regen))
  end

  @doc """
  Persists instructor feedback for a recommendation instance.

  Thumbs feedback is idempotent per user and recommendation instance, while the
  schema shape also supports future text feedback without redefining the
  recommendation identity contract.
  """
  @spec submit_feedback(OracleContext.t(), pos_integer(), map()) ::
          {:ok, RecommendationFeedback.t()} | {:error, term()}
  def submit_feedback(%OracleContext{user_id: user_id} = context, recommendation_id, attrs)
      when is_integer(recommendation_id) and recommendation_id > 0 and is_map(attrs) and
             is_integer(user_id) and user_id > 0 do
    started_at_ms = System.monotonic_time(:millisecond)

    with %RecommendationInstance{} = instance <-
           Repo.get(RecommendationInstance, recommendation_id),
         :ok <- authorize_feedback_context(context, instance) do
      attrs =
        attrs
        |> normalize_feedback_attrs()
        |> Map.put(:recommendation_instance_id, recommendation_id)
        |> Map.put(:user_id, user_id)

      case Map.get(attrs, :feedback_type) do
        feedback_type when feedback_type in [:thumbs_up, :thumbs_down] ->
          result = upsert_sentiment_feedback(instance, attrs)

          emit_lifecycle_telemetry(started_at_ms, context, recommendation_scope(instance), %{
            action: :feedback_submit,
            outcome: feedback_outcome(result),
            feedback_type: Map.get(attrs, :feedback_type),
            error_type: feedback_error_type(result)
          })

          result

        _ ->
          result =
            %RecommendationFeedback{}
            |> RecommendationFeedback.changeset(attrs)
            |> Repo.insert()

          emit_lifecycle_telemetry(started_at_ms, context, recommendation_scope(instance), %{
            action: :feedback_submit,
            outcome: feedback_outcome(result),
            feedback_type: Map.get(attrs, :feedback_type),
            error_type: feedback_error_type(result)
          })

          result
      end
    else
      nil ->
        emit_lifecycle_telemetry(started_at_ms, context, context.scope, %{
          action: :feedback_submit,
          outcome: :error,
          error_type: :recommendation_not_found
        })

        {:error, :recommendation_not_found}

      {:error, reason} = error ->
        emit_lifecycle_telemetry(started_at_ms, context, context.scope, %{
          action: :feedback_submit,
          outcome: :error,
          error_type: error_reason_type(reason)
        })

        error
    end
  end

  def submit_feedback(%OracleContext{} = context, _recommendation_id, _attrs) do
    emit_lifecycle_telemetry(System.monotonic_time(:millisecond), context, context.scope, %{
      action: :feedback_submit,
      outcome: :error,
      error_type: :invalid_user
    })

    {:error, :invalid_user}
  end

  @doc """
  Persists qualitative feedback and sends a best-effort Slack notification.
  """
  @spec submit_additional_feedback(OracleContext.t(), pos_integer(), String.t(), keyword()) ::
          {:ok, RecommendationFeedback.t()} | {:error, term()}
  def submit_additional_feedback(
        %OracleContext{} = context,
        recommendation_id,
        feedback_text,
        opts \\ []
      )
      when is_integer(recommendation_id) and recommendation_id > 0 and is_binary(feedback_text) do
    case submit_feedback(context, recommendation_id, %{
           feedback_type: :additional_text,
           feedback_text: feedback_text
         }) do
      {:ok, feedback} ->
        if instance = Repo.get(RecommendationInstance, recommendation_id) do
          notify_additional_feedback(instance, feedback, context, opts)
        end

        {:ok, feedback}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Merges viewer-specific feedback into a recommendation payload (for example after a PubSub broadcast).
  """
  @spec enrich_feedback_for_viewer(map(), integer()) :: map()
  def enrich_feedback_for_viewer(payload, user_id) when is_map(payload) do
    case Map.get(payload, :id) do
      id when is_integer(id) and id > 0 and is_integer(user_id) and user_id > 0 ->
        Map.put(payload, :feedback_summary, feedback_summary(id, user_id))

      _ ->
        payload
    end
  end

  @doc """
  Returns the latest terminal recommendation instance for a section and scope.
  """
  @spec latest_instance(pos_integer(), Scope.t()) :: RecommendationInstance.t() | nil
  def latest_instance(section_id, %Scope{container_type: :course}) do
    from(ri in RecommendationInstance,
      where:
        ri.section_id == ^section_id and ri.container_type == :course and is_nil(ri.container_id) and
          ri.state in [:ready, :no_signal, :fallback],
      order_by: [desc: ri.inserted_at, desc: ri.id],
      limit: 1
    )
    |> Repo.one()
  end

  def latest_instance(section_id, %Scope{container_type: :container, container_id: container_id}) do
    from(ri in RecommendationInstance,
      where:
        ri.section_id == ^section_id and ri.container_type == :container and
          ri.container_id == ^container_id and ri.state in [:ready, :no_signal, :fallback],
      order_by: [desc: ri.inserted_at, desc: ri.id],
      limit: 1
    )
    |> Repo.one()
  end

  defp latest_generating_instance(section_id, %Scope{container_type: :course}) do
    from(ri in RecommendationInstance,
      where:
        ri.section_id == ^section_id and ri.container_type == :course and is_nil(ri.container_id) and
          ri.state == :generating,
      order_by: [desc: ri.inserted_at, desc: ri.id],
      limit: 1
    )
    |> Repo.one()
  end

  defp latest_generating_instance(section_id, %Scope{
         container_type: :container,
         container_id: container_id
       }) do
    from(ri in RecommendationInstance,
      where:
        ri.section_id == ^section_id and ri.container_type == :container and
          ri.container_id == ^container_id and ri.state == :generating,
      order_by: [desc: ri.inserted_at, desc: ri.id],
      limit: 1
    )
    |> Repo.one()
  end

  defp generate_recommendation(context, scope, section_id, generation_mode, started_at_ms, opts) do
    with {:ok, snapshot_bundle} <- snapshot_bundle(context, opts),
         {:ok, input_contract} <- Builder.build_input_contract(snapshot_bundle.snapshot, opts) do
      case get_in(input_contract, [:signal_summary, :state]) do
        :no_signal ->
          persist_instance(
            context,
            section_id,
            scope,
            generation_mode,
            input_contract,
            %{
              state: :no_signal,
              message: @no_signal_message,
              fallback_reason: :no_signal,
              generated_by_user_id: generated_by_user_id(context, generation_mode)
            },
            started_at_ms,
            opts
          )

        :ready ->
          generate_ready_recommendation(
            context,
            scope,
            section_id,
            generation_mode,
            input_contract,
            started_at_ms,
            opts
          )
      end
    else
      {:error, reason} = error ->
        emit_lifecycle_telemetry(started_at_ms, context, scope, %{
          action: action_for_generation_mode(generation_mode),
          outcome: :error,
          generation_mode: generation_mode,
          rate_limit: rate_limit_for_generation(generation_mode),
          error_type: error_reason_type(reason)
        })

        error
    end
  end

  defp generate_ready_recommendation(
         context,
         scope,
         section_id,
         generation_mode,
         input_contract,
         started_at_ms,
         opts
       ) do
    with {:ok, generating_instance} <-
           create_generating_instance(
             context,
             section_id,
             scope,
             generation_mode,
             input_contract,
             started_at_ms
           ) do
      case load_service_config(section_id) do
        {:ok, service_config} ->
          messages = Prompt.build_messages(input_contract, opts)
          original_prompt = original_prompt(messages)

          case execute_generation(context, scope, service_config, messages, opts) do
            {:ok, %{content: content, metadata: generation_metadata}} ->
              finalize_instance(
                generating_instance,
                context,
                scope,
                input_contract,
                %{
                  state: :ready,
                  message: String.trim(content),
                  fallback_reason: nil,
                  original_prompt: original_prompt,
                  generation_metadata: generation_metadata
                },
                started_at_ms,
                opts
              )

            {:error, _reason} ->
              finalize_instance(
                generating_instance,
                context,
                scope,
                input_contract,
                %{
                  state: :fallback,
                  message: @fallback_message,
                  fallback_reason: :provider_failure,
                  original_prompt: original_prompt
                },
                started_at_ms,
                opts
              )
          end

        {:error, {:missing_feature_config, _reason}} ->
          finalize_instance(
            generating_instance,
            context,
            scope,
            input_contract,
            %{
              state: :fallback,
              message: @fallback_message,
              fallback_reason: :missing_config
            },
            started_at_ms,
            opts
          )
      end
    else
      {:error, _reason} = error ->
        error
    end
  end

  defp execute_generation(context, scope, service_config, messages, opts) do
    request_ctx = %{
      request_type: :generate,
      dashboard_product: :instructor_dashboard,
      feature: @feature,
      user_id: context.user_id,
      section_id: context.dashboard_context_id,
      container_type: scope.container_type,
      container_id: scope.container_id
    }

    case Keyword.get(opts, :execution_fun) do
      execution_fun when is_function(execution_fun, 3) ->
        request_ctx
        |> execution_fun.(messages, service_config)
        |> normalize_generation_result()

      nil ->
        execution_opts =
          case Keyword.get(opts, :completions_mod) do
            nil -> []
            completions_mod -> [completions_mod: completions_mod]
          end

        Execution.generate_with_metadata(
          request_ctx,
          messages,
          [],
          service_config,
          execution_opts
        )
    end
  end

  defp snapshot_bundle(context, opts) do
    case Keyword.get(opts, :snapshot_bundle) do
      %{snapshot: _snapshot} = bundle ->
        {:ok, bundle}

      nil ->
        DataSnapshot.get_or_build(
          %{context: context, consumer_keys: @summary_consumers},
          authorize_fun: &authorize_recommendation_snapshot/2
        )
    end
  end

  defp load_service_config(section_id) do
    {:ok, FeatureConfig.load_for(section_id, @feature)}
  rescue
    error in RuntimeError -> {:error, {:missing_feature_config, error.message}}
  end

  defp active_or_expired_generation(section_id, scope, now) do
    case latest_generating_instance(section_id, scope) do
      nil ->
        :none

      %RecommendationInstance{} = instance ->
        if generation_active?(instance, now) do
          {:ok, instance}
        else
          {:ok, expired_instance} = expire_generation(instance)
          {:expired, expired_instance}
        end
    end
  end

  defp persist_instance(
         context,
         section_id,
         scope,
         generation_mode,
         input_contract,
         attrs,
         started_at_ms,
         opts
       ) do
    metadata =
      %{
        fallback_reason: Map.get(attrs, :fallback_reason),
        prompt_version: input_contract.prompt_version
      }
      |> Map.merge(Map.get(attrs, :generation_metadata, %{}))
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    %RecommendationInstance{}
    |> RecommendationInstance.changeset(%{
      section_id: section_id,
      container_type: scope.container_type,
      container_id: scope.container_id,
      generation_mode: generation_mode,
      state: Map.fetch!(attrs, :state),
      message: Map.fetch!(attrs, :message),
      prompt_version: input_contract.prompt_version,
      prompt_snapshot: input_contract.prompt_snapshot,
      original_prompt: Map.get(attrs, :original_prompt, %{}),
      response_metadata: metadata,
      generated_by_user_id: Map.get(attrs, :generated_by_user_id)
    })
    |> Repo.insert()
    |> case do
      {:ok, instance} ->
        payload = normalize_instance(instance, context.user_id)
        cache_refresh = maybe_refresh_cache(context, scope, payload, opts)

        emit_lifecycle_telemetry(started_at_ms, context, scope, %{
          action: action_for_generation_mode(generation_mode),
          outcome: outcome_for_state(Map.fetch!(attrs, :state)),
          generation_mode: generation_mode,
          rate_limit: rate_limit_for_generation(generation_mode),
          fallback_reason: Map.get(attrs, :fallback_reason),
          cache_refresh: cache_refresh
        })

        LiveSync.broadcast_updated(section_id, scope, normalize_instance(instance, 0))

        {:ok, payload}

      {:error, changeset} ->
        emit_lifecycle_telemetry(started_at_ms, context, scope, %{
          action: action_for_generation_mode(generation_mode),
          outcome: :error,
          generation_mode: generation_mode,
          rate_limit: rate_limit_for_generation(generation_mode),
          error_type: :persistence_failed
        })

        {:error, changeset}
    end
  end

  defp create_generating_instance(
         context,
         section_id,
         scope,
         generation_mode,
         input_contract,
         started_at_ms
       ) do
    %RecommendationInstance{}
    |> RecommendationInstance.changeset(%{
      section_id: section_id,
      container_type: scope.container_type,
      container_id: scope.container_id,
      generation_mode: generation_mode,
      state: :generating,
      message: nil,
      prompt_version: input_contract.prompt_version,
      prompt_snapshot: input_contract.prompt_snapshot,
      original_prompt: %{},
      response_metadata: %{prompt_version: input_contract.prompt_version},
      generated_by_user_id: generated_by_user_id(context, generation_mode)
    })
    |> Repo.insert()
    |> case do
      {:ok, instance} ->
        emit_lifecycle_telemetry(started_at_ms, context, scope, %{
          action: action_for_generation_mode(generation_mode),
          outcome: :started,
          generation_mode: generation_mode,
          rate_limit: rate_limit_for_generation(generation_mode)
        })

        LiveSync.broadcast_generating_started(
          section_id,
          scope,
          normalize_instance(instance, 0)
        )

        {:ok, instance}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp finalize_instance(
         %RecommendationInstance{} = instance,
         context,
         scope,
         input_contract,
         attrs,
         started_at_ms,
         opts
       ) do
    metadata =
      %{
        fallback_reason: Map.get(attrs, :fallback_reason),
        prompt_version: input_contract.prompt_version
      }
      |> Map.merge(Map.get(attrs, :generation_metadata, %{}))
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    instance
    |> RecommendationInstance.changeset(%{
      state: Map.fetch!(attrs, :state),
      message: Map.fetch!(attrs, :message),
      original_prompt: Map.get(attrs, :original_prompt, instance.original_prompt || %{}),
      response_metadata: metadata
    })
    |> Repo.update()
    |> case do
      {:ok, instance} ->
        payload = normalize_instance(instance, context.user_id)
        cache_refresh = maybe_refresh_cache(context, scope, payload, opts)

        emit_lifecycle_telemetry(started_at_ms, context, scope, %{
          action: action_for_generation_mode(instance.generation_mode),
          outcome: outcome_for_state(Map.fetch!(attrs, :state)),
          generation_mode: instance.generation_mode,
          rate_limit: rate_limit_for_generation(instance.generation_mode),
          fallback_reason: Map.get(attrs, :fallback_reason),
          cache_refresh: cache_refresh
        })

        LiveSync.broadcast_updated(instance.section_id, scope, normalize_instance(instance, 0))

        {:ok, payload}

      {:error, changeset} ->
        emit_lifecycle_telemetry(started_at_ms, context, scope, %{
          action: action_for_generation_mode(instance.generation_mode),
          outcome: :error,
          generation_mode: instance.generation_mode,
          rate_limit: rate_limit_for_generation(instance.generation_mode),
          error_type: :persistence_failed
        })

        {:error, changeset}
    end
  end

  defp normalize_instance(instance, user_id) do
    Payload.normalize(%{
      id: instance.id,
      section_id: instance.section_id,
      container_type: instance.container_type,
      container_id: instance.container_id,
      state: instance.state,
      message: instance.message,
      generated_at: instance.inserted_at,
      generation_mode: instance.generation_mode,
      feedback_summary: feedback_summary(instance.id, user_id),
      metadata: instance.response_metadata
    })
  end

  defp within_implicit_window?(
         %RecommendationInstance{inserted_at: inserted_at},
         %DateTime{} = now
       ) do
    DateTime.diff(now, inserted_at, :hour) < @implicit_window_hours
  end

  defp generation_active?(
         %RecommendationInstance{inserted_at: inserted_at},
         %DateTime{} = now
       ) do
    DateTime.diff(now, inserted_at, :second) < @generation_lease_seconds
  end

  defp expire_generation(%RecommendationInstance{} = instance) do
    instance
    |> RecommendationInstance.changeset(%{
      state: :expired,
      message: nil
    })
    |> Repo.update()
  end

  defp generated_by_user_id(_context, :implicit), do: nil
  defp generated_by_user_id(%OracleContext{user_id: user_id}, :explicit_regen), do: user_id

  defp feedback_summary(_recommendation_instance_id, user_id)
       when not is_integer(user_id) or user_id <= 0 do
    %{sentiment_submitted?: false}
  end

  defp feedback_summary(recommendation_instance_id, user_id) do
    case sentiment_feedback(recommendation_instance_id, user_id) do
      %RecommendationFeedback{feedback_type: feedback_type} ->
        %{sentiment_submitted?: true, sentiment: feedback_type}

      nil ->
        %{sentiment_submitted?: false}
    end
  end

  defp sentiment_feedback(recommendation_instance_id, user_id) do
    from(rf in RecommendationFeedback,
      where:
        rf.recommendation_instance_id == ^recommendation_instance_id and rf.user_id == ^user_id and
          rf.feedback_type in [:thumbs_up, :thumbs_down],
      order_by: [desc: rf.inserted_at, desc: rf.id],
      limit: 1
    )
    |> Repo.one()
  end

  defp authorize_recommendation_snapshot(
         %OracleContext{dashboard_context_type: :section} = context,
         _scope
       ) do
    authorize_section_instructor(context)
  end

  defp authorize_recommendation_snapshot(_context, _scope),
    do: {:error, :section_access_denied}

  defp authorize_feedback_context(
         %OracleContext{} = context,
         %RecommendationInstance{section_id: section_id}
       ) do
    case context do
      %OracleContext{dashboard_context_type: :section, dashboard_context_id: ^section_id} ->
        authorize_section_instructor(context)

      _ ->
        {:error, :recommendation_section_mismatch}
    end
  end

  defp authorize_feedback_context(_context, _instance),
    do: {:error, :recommendation_section_mismatch}

  defp authorize_section_instructor(%OracleContext{
         dashboard_context_type: :section,
         dashboard_context_id: section_id,
         user_id: user_id
       })
       when is_integer(section_id) and is_integer(user_id) and user_id > 0 do
    case {Accounts.get_user(user_id, preload: []), Sections.get_section_by(id: section_id)} do
      {%User{} = user, %{slug: slug}} ->
        if Sections.is_instructor?(user, slug) do
          :ok
        else
          {:error, :section_access_denied}
        end

      _ ->
        {:error, :section_access_denied}
    end
  end

  defp authorize_section_instructor(_context), do: {:error, :section_access_denied}

  defp upsert_sentiment_feedback(%RecommendationInstance{id: instance_id}, attrs) do
    feedback_type = Map.fetch!(attrs, :feedback_type)
    user_id = Map.fetch!(attrs, :user_id)

    case sentiment_feedback(instance_id, user_id) do
      %RecommendationFeedback{feedback_type: ^feedback_type} = feedback ->
        {:ok, feedback}

      %RecommendationFeedback{feedback_type: existing_type} ->
        {:error, {:sentiment_already_submitted, existing_type}}

      nil ->
        %RecommendationFeedback{}
        |> RecommendationFeedback.changeset(attrs)
        |> Repo.insert()
    end
  end

  defp normalize_feedback_attrs(attrs) do
    %{
      feedback_type:
        attrs
        |> Map.get(:feedback_type, Map.get(attrs, "feedback_type"))
        |> normalize_feedback_type(),
      feedback_text: Map.get(attrs, :feedback_text, Map.get(attrs, "feedback_text"))
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp normalize_feedback_type(value)
       when value in [:thumbs_up, :thumbs_down, :additional_text],
       do: value

  defp normalize_feedback_type("thumbs_up"), do: :thumbs_up
  defp normalize_feedback_type("thumbs_down"), do: :thumbs_down
  defp normalize_feedback_type("additional_text"), do: :additional_text
  defp normalize_feedback_type(value), do: value

  defp original_prompt(messages) when is_list(messages) do
    %{
      "messages" =>
        Enum.map(messages, fn message ->
          %{
            "role" => message.role |> to_string(),
            "content" => Map.get(message, :content)
          }
        end)
    }
  end

  defp original_prompt(_messages), do: %{}

  defp normalize_generation_result({:ok, content}) when is_binary(content) do
    {:ok, %{content: content, metadata: %{}}}
  end

  defp normalize_generation_result({:ok, %{content: content} = payload})
       when is_binary(content) and is_map(payload) do
    {:ok, %{content: content, metadata: Map.get(payload, :metadata, %{})}}
  end

  defp normalize_generation_result({:error, _reason} = error), do: error
  defp normalize_generation_result(other), do: other

  defp notify_additional_feedback(
         %RecommendationInstance{} = instance,
         %RecommendationFeedback{} = feedback,
         %OracleContext{user_id: user_id},
         opts
       ) do
    slack_fun = Keyword.get(opts, :slack_fun, &Slack.send/1)
    section = Sections.get_section_by(id: instance.section_id)
    user = Accounts.get_user(user_id, preload: [])

    payload =
      FeedbackSlack.payload(%{
        username: user_name(user),
        section_title: Map.get(section || %{}, :title, "Unknown Section"),
        section_slug: Map.get(section || %{}, :slug, "unknown-section"),
        scope_label: formatted_scope_label(instance),
        recommendation_id: instance.id,
        submitted_by: submitted_by(user),
        sentiment: sentiment_for_feedback(instance.id, user_id),
        recommendation_text: instance.message,
        feedback_text: feedback.feedback_text
      })

    case slack_fun.(payload) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to send recommendation feedback to Slack", error: inspect(reason))
        :ok

      _other ->
        :ok
    end
  end

  defp user_name(%User{name: name}) when is_binary(name) and name != "", do: name
  defp user_name(_user), do: "Torus Bot"

  defp submitted_by(%User{} = user), do: CommonUtils.name_and_email(user)
  defp submitted_by(_user), do: "Unknown"

  defp prompt_scope_label(prompt_snapshot) when is_map(prompt_snapshot) do
    scope =
      Map.get(prompt_snapshot, :scope) ||
        Map.get(prompt_snapshot, "scope") ||
        %{}

    Map.get(scope, :scope_label) ||
      Map.get(scope, "scope_label") ||
      "Selected Scope"
  end

  defp prompt_scope_label(_prompt_snapshot), do: "Selected Scope"

  defp formatted_scope_label(%RecommendationInstance{} = instance) do
    scope_label = prompt_scope_label(instance.prompt_snapshot)

    case {instance.container_type, instance.container_id} do
      {:container, container_id} when is_integer(container_id) ->
        "#{scope_label} (container_id: #{container_id})"

      _ ->
        scope_label
    end
  end

  defp sentiment_for_feedback(recommendation_instance_id, user_id) do
    case sentiment_feedback(recommendation_instance_id, user_id) do
      %RecommendationFeedback{feedback_type: feedback_type} -> feedback_type
      nil -> nil
    end
  end

  defp maybe_refresh_cache(context, scope, payload, opts) do
    statuses = [
      write_inprocess_cache(context, scope, payload, opts),
      write_revisit_cache(context, scope, payload, opts)
    ]

    cond do
      Enum.all?(statuses, &(&1 == :skipped)) -> :skipped
      Enum.any?(statuses, &(&1 == :error)) and Enum.any?(statuses, &(&1 == :ok)) -> :partial
      Enum.any?(statuses, &(&1 == :error)) -> :failed
      true -> :ok
    end
  end

  defp write_inprocess_cache(context, scope, payload, opts) do
    cache_opts =
      opts
      |> Keyword.take([:inprocess_store])
      |> Keyword.put(:key_meta, @cache_key_meta)

    case Keyword.get(cache_opts, :inprocess_store) do
      nil ->
        :skipped

      _store ->
        case Cache.write_oracle(context, scope, @oracle_key, payload, @cache_key_meta, cache_opts) do
          :ok -> :ok
          {:error, _reason} -> :error
        end
    end
  end

  defp write_revisit_cache(%OracleContext{user_id: user_id} = context, scope, payload, opts)
       when is_integer(user_id) and user_id > 0 do
    case Keyword.get(opts, :revisit_cache) do
      nil ->
        :skipped

      revisit_cache ->
        with {:ok, revisit_key} <-
               Key.revisit(user_id, context, scope, @oracle_key, @cache_key_meta),
             :ok <- safe_revisit_write(revisit_cache, revisit_key, payload) do
          :ok
        else
          _ -> :error
        end
    end
  end

  defp write_revisit_cache(_context, _scope, _payload, _opts), do: :skipped

  defp safe_revisit_write(revisit_cache, revisit_key, payload) do
    try do
      RevisitCache.write(revisit_cache, revisit_key, payload)
    catch
      :exit, _reason -> {:error, :revisit_cache_unavailable}
    end
  end

  defp emit_lifecycle_telemetry(started_at_ms, context, scope, metadata) do
    Telemetry.lifecycle_stop(
      %{duration_ms: elapsed_ms(started_at_ms)},
      Map.merge(
        %{
          container_type: Map.get(scope || %{}, :container_type),
          dashboard_context_type: context.dashboard_context_type
        },
        metadata
      )
    )
  end

  defp elapsed_ms(started_at_ms) when is_integer(started_at_ms) do
    max(System.monotonic_time(:millisecond) - started_at_ms, 0)
  end

  defp action_for_generation_mode(:implicit), do: :implicit_generate
  defp action_for_generation_mode(:explicit_regen), do: :explicit_regen

  defp normalize_action(:implicit), do: :implicit_generate
  defp normalize_action(:explicit_regen), do: :explicit_regen
  defp normalize_action(_), do: :unknown

  defp rate_limit_for_generation(:implicit), do: :miss
  defp rate_limit_for_generation(:explicit_regen), do: nil

  defp outcome_for_state(:generating), do: :started
  defp outcome_for_state(:ready), do: :generated
  defp outcome_for_state(:no_signal), do: :no_signal
  defp outcome_for_state(:fallback), do: :fallback
  defp outcome_for_state(:expired), do: :expired

  defp recommendation_scope(%RecommendationInstance{container_type: :course}),
    do: %Scope{container_type: :course, container_id: nil}

  defp recommendation_scope(%RecommendationInstance{
         container_type: :container,
         container_id: id
       }),
       do: %Scope{container_type: :container, container_id: id}

  defp feedback_outcome(
         {:ok, %RecommendationFeedback{id: id, inserted_at: inserted_at, updated_at: updated_at}}
       )
       when is_integer(id) and inserted_at == updated_at,
       do: :accepted

  defp feedback_outcome({:ok, %RecommendationFeedback{}}), do: :idempotent
  defp feedback_outcome({:error, {:sentiment_already_submitted, _existing}}), do: :rejected
  defp feedback_outcome({:error, _reason}), do: :error

  defp feedback_error_type({:error, reason}), do: error_reason_type(reason)
  defp feedback_error_type(_), do: nil

  defp error_reason_type(reason) when is_atom(reason), do: reason
  defp error_reason_type({reason, _details}) when is_atom(reason), do: reason
  defp error_reason_type(_reason), do: :unknown
end
