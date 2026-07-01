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
  alias Oli.InstructorDashboard.Email.{EmailContext, LinkValidator, PromptComposer, Substitution}

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

  Returns `{:ok, %{subject_template, body_template, metadata}}` where
  `body_template` is markdown. Callers that hand this to
  `Oli.InstructorDashboard.Email.send_emails/2` must first convert
  `body_template` to Slate JSON (the modal mediates this).

  ## Options

    * `:execution_fun` — `(request_ctx, messages, service_config) ->
      {:ok, %{content, metadata}} | {:error, term()}`. Bypasses
      `Oli.GenAI.Execution`. Used in tests.
    * `:completions_mod` — overrides the default completions adapter.
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

        # Don't emit `raw_reason` — provider payloads may contain prompts/tokens/PII.
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
    provider_opts = [response_format: %{type: "json_object"}]

    case Keyword.get(opts, :execution_fun) do
      execution_fun when is_function(execution_fun, 4) ->
        execution_fun.(request_ctx, messages, service_config, provider_opts: provider_opts)

      execution_fun when is_function(execution_fun, 3) ->
        execution_fun.(request_ctx, messages, service_config)

      nil ->
        execution_opts =
          case Keyword.get(opts, :completions_mod) do
            nil -> [provider_opts: provider_opts]
            completions_mod -> [completions_mod: completions_mod, provider_opts: provider_opts]
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
    case extract_templates(content) do
      {:ok, subject, body} ->
        {sanitized_body, stripped_count} = sanitize_links(body)
        maybe_emit_link_stripped(stripped_count, context)
        {:ok, %{subject_template: subject, body_template: sanitized_body}}

      :error ->
        {:error, :parse_failure}
    end
  end

  defp parse_response(_, _), do: {:error, :parse_failure}

  defp extract_templates(content) do
    content
    |> extract_json_object()
    |> escape_newlines_in_strings()
    |> Jason.decode()
    |> case do
      {:ok, %{"subject" => s, "body" => b}} when is_binary(s) and is_binary(b) ->
        subject = String.trim(s)
        body = String.trim(b)

        with true <- subject != "" and body != "",
             true <- Substitution.unsupported_tokens(subject) == [],
             true <- Substitution.unsupported_tokens(body) == [] do
          {:ok, subject, body}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp extract_json_object(content) do
    with {:ok, from_open} <- skip_until(String.trim(content), ?{),
         {:ok, from_close_rev} <- skip_until(String.reverse(from_open), ?}) do
      String.reverse(from_close_rev)
    else
      :error -> String.trim(content)
    end
  end

  defp skip_until(<<char, _::binary>> = bin, char), do: {:ok, bin}
  defp skip_until(<<_, rest::binary>>, char), do: skip_until(rest, char)
  defp skip_until(<<>>, _char), do: :error

  defp escape_newlines_in_strings(content) do
    content
    |> String.to_charlist()
    |> do_escape_newlines(false, false, [])
    |> Enum.reverse()
    |> List.to_string()
  end

  defp do_escape_newlines([], _in_str, _escaped, acc), do: acc

  defp do_escape_newlines([?\\ | rest], true, false, acc),
    do: do_escape_newlines(rest, true, true, [?\\ | acc])

  defp do_escape_newlines([c | rest], true, true, acc),
    do: do_escape_newlines(rest, true, false, [c | acc])

  defp do_escape_newlines([?" | rest], true, false, acc),
    do: do_escape_newlines(rest, false, false, [?" | acc])

  defp do_escape_newlines([?" | rest], false, false, acc),
    do: do_escape_newlines(rest, true, false, [?" | acc])

  defp do_escape_newlines([?\n | rest], true, false, acc),
    do: do_escape_newlines(rest, true, false, [?n, ?\\ | acc])

  defp do_escape_newlines([?\r | rest], true, false, acc),
    do: do_escape_newlines(rest, true, false, [?r, ?\\ | acc])

  defp do_escape_newlines([c | rest], in_str, false, acc),
    do: do_escape_newlines(rest, in_str, false, [c | acc])

  @markdown_link_regex ~r/\[([^\]]*)\]\(([^)]+)\)/
  @autolink_regex ~r/<https?:\/\/[^>]+>/i
  @bare_url_regex ~r/(?:https?:)?\/\/[^\s)\]"<>]+/i

  defp sanitize_links(body) do
    {body, link_count} =
      @markdown_link_regex
      |> Regex.scan(body, return: :index)
      |> Enum.reverse()
      |> Enum.reduce({body, 0}, fn match, {acc, count} ->
        replace_link_if_invalid(acc, match, count)
      end)

    {body, autolink_count} = strip_all(@autolink_regex, body)
    {body, bare_count} = strip_all(@bare_url_regex, body)

    {body, link_count + autolink_count + bare_count}
  end

  defp strip_all(regex, body) do
    count = length(Regex.scan(regex, body))
    {Regex.replace(regex, body, ""), count}
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

  defp valid_internal_path?(url), do: LinkValidator.valid_internal_path?(url)

  defp maybe_emit_link_stripped(0, _context), do: :ok

  defp maybe_emit_link_stripped(count, %EmailContext{} = context) do
    :telemetry.execute(
      [:oli, :instructor_dashboard, :email, :draft, :link_stripped],
      %{count: count},
      %{
        feature: @feature,
        section_id: context.section_id,
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
      section_id: context.section_id,
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
