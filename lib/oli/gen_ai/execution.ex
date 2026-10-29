defmodule Oli.GenAI.Execution do
  @moduledoc "Bounded request execution with one guarded pre-output backup attempt; no health mutations."
  alias Oli.GenAI.{Router, Telemetry}
  alias Oli.GenAI.Completions
  alias Oli.GenAI.Completions.ServiceConfig

  @doc "Returns a synchronous completion through the selected tier pool."
  def generate(ctx, messages, functions, %ServiceConfig{} = config, opts \\ []) do
    case generate_with_metadata(ctx, messages, functions, config, opts) do
      {:ok, %{content: content}} -> {:ok, content}
      error -> error
    end
  end

  @doc "Returns completion content and the identity of the attempt which produced it."
  def generate_with_metadata(ctx, messages, functions, config, opts \\ []),
    do: execute(:generate, ctx, messages, functions, config, nil, opts)

  @doc "Streams through the selected pool, with cancellation and a total inference deadline."
  def stream(ctx, messages, functions, %ServiceConfig{} = config, handler, opts \\ []),
    do: execute(:stream, ctx, messages, functions, config, handler, opts)

  @doc "Executes an explicitly selected administrative pool with the same bounded ownership as production."
  def generate_in_plan(messages, functions, %Oli.GenAI.RoutingPlan{} = plan, opts \\ []) do
    config = %ServiceConfig{id: plan.service_config_id}

    case execute(:generate, %{}, messages, functions, config, nil, opts, plan) do
      {:ok, %{content: content}} -> {:ok, content}
      error -> error
    end
  end

  defp execute(mode, ctx, messages, functions, config, handler, opts, selected \\ nil) do
    timeout = Keyword.get(opts, :total_timeout_ms, 300_000)

    case is_integer(timeout) and timeout > 0 do
      false ->
        {:error, :invalid_deadline}

      true ->
        deadline = System.monotonic_time(:millisecond) + timeout
        owner = self()
        token = make_ref()

        {worker, monitor} =
          spawn_monitor(fn ->
            guard(owner, config.id, deadline)
            Process.put(:genai_output_exposed, false)

            result =
              try do
                with {:ok, plan} <- select_plan(selected, ctx, mode, config) do
                  attempt(
                    mode,
                    ctx,
                    messages,
                    functions,
                    config,
                    plan,
                    owner,
                    token,
                    Keyword.put(opts, :deadline, deadline)
                  )
                end
              rescue
                _ -> {:error, :application_error}
              catch
                _, _ -> {:error, :application_error}
              end

            result =
              case {result, Process.get(:genai_output_exposed)} do
                {{:error, _}, true} -> {:error, :interrupted_stream}
                _ -> result
              end

            send(owner, {token, :result, result})
          end)

        try do
          result =
            await(worker, monitor, token, handler, Keyword.get(opts, :on_plan), deadline, false)

          :telemetry.execute(
            [:oli, :genai, :request, :stop],
            %{duration_ms: timeout - max(deadline - System.monotonic_time(:millisecond), 0)},
            %{
              service_config_id: config.id,
              request_type: mode,
              error_category: safe_category(result),
              outcome:
                case result do
                  {:error, _} -> :error
                  _ -> :ok
                end
            }
          )

          result
        after
          cleanup_ref = Process.monitor(worker)
          Process.exit(worker, :kill)

          receive do
            {:DOWN, ^cleanup_ref, :process, ^worker, _} -> :ok
          end

          Process.demonitor(monitor, [:flush])
          flush(token)
        end
    end
  end

  defp select_plan(nil, ctx, mode, config),
    do: Router.route(Map.put(ctx, :request_type, mode), config)

  defp select_plan(plan, _, _, _), do: {:ok, plan}

  # Install owner monitoring before any I/O. This is lifecycle supervision, not capacity accounting.
  defp guard(owner, config_id, deadline) do
    worker = self()

    spawn(fn ->
      owner_ref = Process.monitor(owner)
      worker_ref = Process.monitor(worker)
      send(worker, :guard_ready)

      receive do
        {:DOWN, ^owner_ref, :process, _, _} ->
          Process.exit(worker, :kill)

          :telemetry.execute([:oli, :genai, :request, :cancelled], %{count: 1}, %{
            service_config_id: config_id
          })

        {:DOWN, ^worker_ref, :process, _, _} ->
          :ok
      after
        max(deadline - System.monotonic_time(:millisecond), 0) -> Process.exit(worker, :kill)
      end
    end)

    receive do
      :guard_ready -> :ok
    end
  end

  defp attempt(mode, ctx, messages, functions, config, plan, owner, token, opts) do
    send(owner, {token, :plan, plan})

    receive do
      {^token, :plan_ready} -> :ok
    end

    started = System.monotonic_time(:millisecond)

    callback = fn
      {:error, reason} ->
        Process.put(:genai_stream_error, reason)

      {:error} ->
        Process.put(:genai_stream_error, :stream_error)

      :error ->
        Process.put(:genai_stream_error, :stream_error)

      [] ->
        :ok

      event ->
        case Process.get(:genai_output_exposed) do
          false ->
            :telemetry.execute(
              [:oli, :genai, :request, :first_output],
              %{duration_ms: System.monotonic_time(:millisecond) - started},
              %{service_config_id: config.id, tier: plan.tier}
            )

          true ->
            :ok
        end

        Process.put(:genai_output_exposed, true)
        send(owner, {token, :event, event})

        receive do
          {^token, :event_ready} -> :ok
        end
    end

    Process.delete(:genai_stream_error)
    result = dispatch(mode, messages, functions, plan, callback, opts)

    result =
      case Process.get(:genai_stream_error) do
        nil -> result
        error -> {:error, error}
      end

    Telemetry.provider_stop(
      %{duration_ms: System.monotonic_time(:millisecond) - started},
      %{
        service_config_id: config.id,
        registered_model_id: plan.selected_model.id,
        provider: plan.provider.adapter,
        tier: plan.tier,
        request_type: mode,
        error_category: safe_category(result),
        http_status:
          case result do
            {:error, %{http_status: status}} -> status
            _ -> nil
          end,
        outcome:
          case result do
            {:error, _} -> :error
            _ -> :ok
          end
      }
    )

    case result do
      {:error, reason}
      when plan.tier in [:primary, :secondary] and not is_nil(plan.provider) and
             plan.reason != :kill_switch_primary_only ->
        case not Process.get(:genai_output_exposed) and retryable?(reason) and
               System.monotonic_time(:millisecond) < opts[:deadline] do
          true ->
            case Router.backup(ctx, config, plan.provider.id) do
              {:ok, backup} ->
                :telemetry.execute([:oli, :genai, :request, :backup], %{count: 1}, %{
                  service_config_id: config.id
                })

                attempt(mode, ctx, messages, functions, config, backup, owner, token, opts)

              _ ->
                result
            end

          false ->
            result
        end

      {:ok, content} when mode == :generate ->
        {:ok,
         %{
           content: content,
           metadata: %{
             model: plan.selected_model.model,
             provider: plan.provider.adapter,
             registered_model_id: plan.selected_model.id,
             service_config_id: config.id
           }
         }}

      _ ->
        result
    end
  end

  defp dispatch(mode, messages, functions, plan, callback, opts) do
    module = Keyword.get(opts, :completions_mod, Completions)
    provider_opts = opts[:provider_opts] || []

    case {module, mode} do
      {Completions, :generate} ->
        Completions.generate(
          messages,
          functions,
          plan.selected_model,
          Keyword.merge(provider_opts, transport_context: plan, deadline: opts[:deadline])
        )

      {Completions, :stream} ->
        Completions.stream(
          messages,
          functions,
          plan.selected_model,
          callback,
          Keyword.merge(provider_opts, transport_context: plan, deadline: opts[:deadline])
        )

      {_, :generate} ->
        module.generate(messages, functions, plan.selected_model, provider_opts)

      {_, :stream} ->
        module.stream(messages, functions, plan.selected_model, callback)
    end
  end

  defp safe_category({:error, %{http_status: status}}) when is_integer(status), do: :http_error

  defp safe_category({:error, reason})
       when reason in [
              :busy,
              :pool_unavailable,
              :stale_configuration,
              :configuration_unavailable,
              :provider_ineligible,
              :backup_unavailable,
              :invalid_configuration,
              :application_error,
              :inference_deadline,
              :interrupted_stream,
              :truncated_stream,
              :invalid_response,
              :response_timeout,
              :connection_failure,
              :response_too_large,
              :transport_error
            ],
       do: reason

  defp safe_category({:error, _}), do: :request_error
  defp safe_category(_), do: nil

  defp retryable?(reason)
       when reason in [
              :connection_failure,
              :response_timeout,
              :econnrefused,
              :closed,
              :nxdomain,
              :connect_timeout
            ],
       do: true

  defp retryable?(%{http_status: status}), do: status in [500, 502, 503, 504]
  defp retryable?(_), do: false

  defp await(worker, monitor, token, handler, on_plan, deadline, exposed) do
    case System.monotonic_time(:millisecond) < deadline do
      false ->
        {:error,
         case exposed do
           true -> :interrupted_stream
           false -> :inference_deadline
         end}

      true ->
        receive_result(worker, monitor, token, handler, on_plan, deadline, exposed)
    end
  end

  defp receive_result(worker, monitor, token, handler, on_plan, deadline, exposed) do
    receive do
      {^token, :plan, plan} ->
        case on_plan do
          nil -> :ok
          callback -> callback.(plan)
        end

        send(worker, {token, :plan_ready})

        await(worker, monitor, token, handler, on_plan, deadline, exposed)

      {^token, :event, event} ->
        handler.(event)
        send(worker, {token, :event_ready})
        await(worker, monitor, token, handler, on_plan, deadline, true)

      {^token, :result, result} ->
        case System.monotonic_time(:millisecond) >= deadline do
          true ->
            {:error,
             case exposed do
               true -> :interrupted_stream
               false -> :inference_deadline
             end}

          false ->
            result
        end

      {:DOWN, ^monitor, :process, ^worker, _} ->
        {:error,
         case exposed do
           true ->
             :interrupted_stream

           false ->
             case System.monotonic_time(:millisecond) >= deadline do
               true -> :inference_deadline
               false -> :application_error
             end
         end}
    after
      max(deadline - System.monotonic_time(:millisecond), 0) ->
        {:error,
         case exposed do
           true -> :interrupted_stream
           false -> :inference_deadline
         end}
    end
  end

  defp flush(token) do
    receive do
      {^token, _, _} -> flush(token)
    after
      0 -> :ok
    end
  end
end
