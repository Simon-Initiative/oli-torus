defmodule Oli.InstructorDashboard.Email.AIDraftFacade do
  @moduledoc """
  Generates AI email drafts (subject + body templates) for the instructor
  dashboard.

  Composes a prompt via `PromptComposer`, resolves the GenAI ServiceConfig
  for the `:instructor_email` feature, calls the synchronous completion path
  via `Oli.GenAI.Execution.generate_with_metadata/5`, parses the JSON response,
  and returns `{:ok, %{subject_template, body_template, metadata}}` or a coarse
  `{:error, reason}` tuple suitable for surfacing in the modal UI.

  Mirrors the dependency-injection pattern from
  `Oli.InstructorDashboard.Recommendations.execute_generation/5`: callers can
  pass `:execution_fun` in opts to bypass the real provider during tests.

  See `docs/exec-plans/current/epics/intelligent_dashboard/email_sending/plan.md`
  Phase 1 step 1.3 architectural decisions (1.3.a–1.3.e).
  """

  alias Oli.GenAI.Execution
  alias Oli.GenAI.FeatureConfig
  alias Oli.InstructorDashboard.Email.{EmailContext, PromptComposer, Substitution}

  @feature :instructor_email

  @type ok_result ::
          {:ok,
           %{
             subject_template: String.t(),
             body_template: String.t(),
             metadata: map()
           }}

  @type error_reason ::
          :missing_feature_config | :timeout | :provider_error | :parse_failure

  @type error_result :: {:error, error_reason()}

  # Bound the inspected representation of upstream errors so telemetry never
  # serializes a full provider response body (which can contain prompt or
  # message-content fragments).
  @inspect_opts [limit: 100, printable_limit: 200]

  @doc """
  Generates an AI email draft from the given `EmailContext`.

  All upstream errors (from `Oli.GenAI.Execution`, JSON parsing, and missing
  feature configuration) are coerced into a small, fixed set of reasons
  (`error_reason/0`) so callers do not depend on provider-specific error
  shapes. The richer underlying reason is logged via `:telemetry` for
  diagnostics with `inspect/2` output bounded to avoid leaking content.

  ## Options

    * `:execution_fun` — `(request_ctx, messages, service_config) ->
      {:ok, %{content, metadata}} | {:error, term()}`. When provided, bypasses
      `Oli.GenAI.Execution`. Used in tests.
    * `:completions_mod` — module name to override the default completions
      adapter when calling the real Execution path.
  """
  @spec generate(EmailContext.t(), keyword()) :: ok_result() | error_result()
  def generate(%EmailContext{} = context, opts \\ []) do
    started_at_ms = System.monotonic_time(:millisecond)
    messages = PromptComposer.compose(context)
    request_ctx = build_request_ctx(context)

    with {:ok, service_config} <- load_service_config(context.section_id),
         {:ok, %{content: content, metadata: metadata}} <-
           call_execution(request_ctx, messages, service_config, opts) do
      case parse_response(content) do
        {:ok, parsed} ->
          emit_event(:generated, context, started_at_ms, metadata)
          {:ok, Map.put(parsed, :metadata, metadata)}

        {:error, :parse_failure} ->
          emit_event(:failed, context, started_at_ms, %{reason: :parse_failure})
          {:error, :parse_failure}
      end
    else
      {:error, {:missing_feature_config, _msg}} ->
        emit_event(:failed, context, started_at_ms, %{reason: :missing_feature_config})
        {:error, :missing_feature_config}

      {:error, reason} ->
        coarse = coerce_execution_error(reason)

        emit_event(:failed, context, started_at_ms, %{
          reason: coarse,
          raw_reason: inspect(reason, @inspect_opts)
        })

        {:error, coarse}
    end
  end

  defp load_service_config(section_id) do
    {:ok, FeatureConfig.load_for(section_id, @feature)}
  rescue
    # Narrow rescue mirrors `Oli.InstructorDashboard.Recommendations.load_service_config/1`
    # — only `RuntimeError` (the explicit `raise` in `FeatureConfig.load_for/2`
    # when no row matches) is treated as a missing-config error. DB faults
    # (`Ecto.QueryError`, `DBConnection.ConnectionError`) intentionally
    # propagate so the supervision tree handles them, matching sibling pattern.
    error in RuntimeError -> {:error, {:missing_feature_config, error.message}}
  end

  defp build_request_ctx(%EmailContext{} = context) do
    %{
      request_type: :generate,
      dashboard_product: :instructor_dashboard,
      feature: @feature,
      section_id: context.section_id,
      situation_key: context.situation_key,
      tone: context.tone,
      recipient_count: context.recipient_count
    }
  end

  defp call_execution(request_ctx, messages, service_config, opts) do
    case Keyword.get(opts, :execution_fun) do
      execution_fun when is_function(execution_fun, 3) ->
        execution_fun.(request_ctx, messages, service_config)

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

  defp parse_response(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, %{"subject" => subject, "body" => body}}
      when is_binary(subject) and is_binary(body) and subject != "" and body != "" ->
        if Substitution.unsupported_tokens(subject) == [] and
             Substitution.unsupported_tokens(body) == [] do
          {:ok, %{subject_template: subject, body_template: body}}
        else
          {:error, :parse_failure}
        end

      _ ->
        {:error, :parse_failure}
    end
  end

  defp parse_response(_), do: {:error, :parse_failure}

  defp coerce_execution_error(:timeout), do: :timeout
  defp coerce_execution_error(:connect_timeout), do: :timeout
  defp coerce_execution_error(:recv_timeout), do: :timeout
  defp coerce_execution_error({:timeout, _}), do: :timeout
  defp coerce_execution_error(_), do: :provider_error

  defp emit_event(outcome, %EmailContext{} = context, started_at_ms, extra)
       when outcome in [:generated, :failed] do
    duration_ms = System.monotonic_time(:millisecond) - started_at_ms

    base_metadata = %{
      feature: @feature,
      situation_key: context.situation_key,
      tone: context.tone,
      recipient_count: context.recipient_count
    }

    :telemetry.execute(
      [:oli, :instructor_dashboard, :email, :draft, outcome],
      %{duration_ms: duration_ms},
      Map.merge(base_metadata, extra)
    )
  end
end
