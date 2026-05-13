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

  @doc """
  Generates an AI email draft from the given `EmailContext`.

  Returns `{:ok, %{subject_template, body_template, metadata}}` — both
  templates are **markdown strings** containing whitelist placeholders
  (`{first_name}`, etc.). The body may include relative-path markdown links
  surviving the link sanitizer (`[label](/sections/...)`).

  ## Shape handoff to `Oli.InstructorDashboard.Email.send_emails/2`

  `Email.validate/2` and `Email.send_emails/2` accept `%{subject, body_slate}`
  — `body_slate` is Slate JSON (a list of element maps). The shapes differ
  by design: the Phase 4 modal LiveView is responsible for converting the
  AI's markdown `body_template` into Slate JSON for in-modal editing
  (see plan §4.5), and submits the EDITED Slate JSON to `send_emails/2`
  on Send. Callers must not pass the raw `generate/2` result to
  `send_emails/2` without that conversion.

  All upstream errors (from `Oli.GenAI.Execution`, JSON parsing, and missing
  feature configuration) are coerced into a small, fixed set of reasons
  (`error_reason/0`) so callers do not depend on provider-specific error
  shapes.

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
      case parse_response(content, context) do
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

        # Do NOT include `raw_reason` in telemetry — provider error payloads
        # may contain prompt fragments, headers, tokens, or student data.
        # The coarse atom is sufficient for handlers; full reason is logged
        # via Logger if a richer signal is needed.
        emit_event(:failed, context, started_at_ms, %{reason: coarse})

        {:error, coarse}
    end
  end

  defp load_service_config(section_id) do
    FeatureConfig.load_for(section_id, @feature)
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

  defp parse_response(content, context) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, %{"subject" => subject, "body" => body}}
      when is_binary(subject) and is_binary(body) and subject != "" and body != "" ->
        if Substitution.unsupported_tokens(subject) == [] and
             Substitution.unsupported_tokens(body) == [] do
          {sanitized_body, stripped_count} = sanitize_links(body)
          maybe_emit_link_stripped(stripped_count, context)
          {:ok, %{subject_template: subject, body_template: sanitized_body}}
        else
          {:error, :parse_failure}
        end

      _ ->
        {:error, :parse_failure}
    end
  end

  defp parse_response(_, _), do: {:error, :parse_failure}

  @markdown_link_regex ~r/\[([^\]]*)\]\(([^)]+)\)/

  # Strip markdown links whose URL is not a verified internal relative path.
  # Returns {sanitized_body, stripped_link_count}.
  defp sanitize_links(body) do
    @markdown_link_regex
    |> Regex.scan(body, return: :index)
    |> Enum.reverse()
    |> Enum.reduce({body, 0}, fn match, {acc, count} ->
      replace_link_if_invalid(acc, match, count)
    end)
  end

  defp replace_link_if_invalid(
         body,
         [{full_start, full_len}, {lbl_start, lbl_len}, {url_start, url_len}],
         count
       ) do
    label = binary_part(body, lbl_start, lbl_len)
    url = binary_part(body, url_start, url_len)

    if valid_internal_path?(url) do
      {body, count}
    else
      prefix = binary_part(body, 0, full_start)
      suffix = binary_part(body, full_start + full_len, byte_size(body) - full_start - full_len)
      {prefix <> label <> suffix, count + 1}
    end
  end

  defp valid_internal_path?(url) when is_binary(url) do
    uri = URI.parse(url)

    cond do
      not is_nil(uri.scheme) -> false
      not is_nil(uri.host) -> false
      is_nil(uri.path) -> false
      not String.starts_with?(uri.path, "/") -> false
      String.contains?(uri.path, "..") -> false
      true -> Phoenix.Router.route_info(OliWeb.Router, "GET", uri.path, "_") != :error
    end
  end

  defp maybe_emit_link_stripped(0, _context), do: :ok

  defp maybe_emit_link_stripped(count, %EmailContext{} = context) do
    :telemetry.execute(
      [:oli, :instructor_dashboard, :email, :draft, :link_stripped],
      %{count: count},
      %{
        feature: @feature,
        situation_key: context.situation_key,
        tone: context.tone,
        recipient_count: context.recipient_count
      }
    )

    :ok
  end

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
