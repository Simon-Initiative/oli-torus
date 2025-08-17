defmodule Oli.GenAI.Agent.Server do
  use GenServer
  require Logger

  alias Oli.GenAI.Agent.{Decision, LLMBridge, ToolBroker, Persistence, PubSub, Summarizer, Critic}

  defmodule Step do
    @enforce_keys [:num, :action, :observation]
    defstruct [
      :num,
      :action,
      :observation,
      :rationale_summary,
      :latency_ms,
      :tokens_in,
      :tokens_out
    ]

    @type t :: %__MODULE__{
            num: integer(),
            action: map(),
            observation: term(),
            rationale_summary: String.t() | nil,
            latency_ms: integer() | nil,
            tokens_in: integer() | nil,
            tokens_out: integer() | nil
          }
  end

  defmodule State do
    defstruct [
      :id,
      :goal,
      :plan,
      # :idle | :thinking | :acting | :awaiting_tool | :done | :error | :paused | :cancelled
      :status,
      :budgets,
      :service_config,
      :policy,
      :context_summary,
      :short_window,
      :steps,
      :inflight,
      :metadata,
      :tokens_used,
      :cost_cents,
      :start_time
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            goal: String.t(),
            plan: [String.t()],
            status: atom(),
            budgets: map(),
            service_config: map() | nil,
            policy: module() | nil,
            context_summary: String.t(),
            short_window: [map()],
            steps: [Step.t()],
            inflight: map(),
            metadata: map(),
            tokens_used: integer(),
            cost_cents: integer(),
            start_time: DateTime.t()
          }
  end

  # Client API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(args[:run_id]))
  end

  def pause(run_id) do
    GenServer.call(via_tuple(run_id), :pause)
  end

  def resume(run_id) do
    GenServer.call(via_tuple(run_id), :resume)
  end

  def cancel(run_id) do
    GenServer.call(via_tuple(run_id), :cancel)
  end

  def status(run_id) do
    GenServer.call(via_tuple(run_id), :status)
  end

  def info(run_id) do
    GenServer.call(via_tuple(run_id), :info)
  end

  def whereis(run_id) do
    case Registry.lookup(Oli.GenAI.Agent.Registry, run_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  # Server Callbacks

  @impl true
  def init(args) do
    id = Map.get(args, :run_id, Ecto.UUID.generate())

    state = %State{
      id: id,
      goal: Map.fetch!(args, :goal),
      plan: Map.get(args, :plan, []),
      status: :idle,
      budgets: Map.get(args, :budgets, default_budgets()),
      service_config: Map.get(args, :service_config),
      policy: Map.get(args, :policy),
      context_summary: Map.get(args, :context_summary, ""),
      short_window: Map.get(args, :initial_messages, []),
      steps: [],
      inflight: %{},
      metadata: Map.get(args, :metadata, %{}),
      tokens_used: 0,
      cost_cents: 0,
      start_time: DateTime.utc_now()
    }

    # Persist the run
    {:ok, _run} =
      Persistence.create_run(%{
        id: id,
        goal: state.goal,
        run_type: Map.get(args, :run_type, "general"),
        plan: %{steps: state.plan},
        status: "running",
        budgets: state.budgets,
        metadata: state.metadata
      })

    # Start the loop
    Process.send_after(self(), :step, 0)

    {:ok, state}
  end

  @impl true
  def handle_call(:pause, _from, state) do
    new_state = %{state | status: :paused}
    PubSub.broadcast_status(state.id, %{status: :paused})
    {:reply, :ok, new_state}
  end

  def handle_call(:resume, _from, %{status: :paused} = state) do
    new_state = %{state | status: :idle}
    PubSub.broadcast_status(state.id, %{status: :idle})
    Process.send_after(self(), :step, 0)
    {:reply, :ok, new_state}
  end

  def handle_call(:resume, _from, state) do
    {:reply, {:error, "Not paused"}, state}
  end

  def handle_call(:cancel, _from, state) do
    new_state = %{state | status: :cancelled}
    PubSub.broadcast_status(state.id, %{status: :cancelled})
    Persistence.update_run(state.id, %{status: "cancelled", finished_at: DateTime.utc_now()})
    {:reply, :ok, new_state}
  end

  def handle_call(:status, _from, state) do
    status_info = %{
      id: state.id,
      status: state.status,
      goal: state.goal,
      plan: state.plan,
      steps_completed: length(state.steps)
    }

    {:reply, {:ok, status_info}, state}
  end

  def handle_call(:info, _from, state) do
    info = %{
      id: state.id,
      status: state.status,
      goal: state.goal,
      plan: state.plan,
      steps_completed: length(state.steps),
      last_step: List.first(state.steps),
      budgets: state.budgets,
      context_summary: state.context_summary,
      metadata: state.metadata,
      tokens_used: state.tokens_used,
      cost_cents: state.cost_cents
    }

    {:reply, {:ok, info}, state}
  end

  @impl true
  def handle_info(:step, %{status: status} = state)
      when status in [:paused, :cancelled, :done, :error] do
    # Don't process steps when paused, cancelled, done, or in error
    {:noreply, state}
  end

  def handle_info(:step, %{status: :awaiting_tool} = state) do
    # Wait for tool to complete
    {:noreply, state}
  end

  def handle_info(:step, state) do
    state = %{state | status: :thinking}

    # Check budgets and policy
    case check_stop_conditions(state) do
      {:stop, reason} ->
        Logger.info("Agent stopping: #{reason}")
        finalize_run(state, reason)

      :continue ->
        process_think_phase(state)
    end
  end

  def handle_info({:tool_result, call_id, result}, %{inflight: inflight} = state) do
    case Map.get(inflight, call_id) do
      nil ->
        Logger.warning("Received result for unknown tool call: #{call_id}")
        {:noreply, state}

      tool_info ->
        state = handle_tool_observation(state, tool_info, result)
        new_inflight = Map.delete(inflight, call_id)
        new_state = %{state | inflight: new_inflight, status: :idle}

        # Schedule next step
        Process.send_after(self(), :step, 100)
        {:noreply, new_state}
    end
  end

  # Private functions

  defp via_tuple(run_id) do
    {:via, Registry, {Oli.GenAI.Agent.Registry, run_id}}
  end

  defp default_budgets do
    %{
      max_steps: 50,
      max_tokens: 100_000,
      max_cost_cents: 1000,
      deadline_at: DateTime.add(DateTime.utc_now(), 300, :second)
    }
  end

  defp check_stop_conditions(state) do
    cond do
      # Check step limit
      length(state.steps) >= state.budgets.max_steps ->
        {:stop, "Step limit reached"}

      # Check token budget
      state.tokens_used >= state.budgets.max_tokens ->
        {:stop, "Token budget exceeded"}

      # Check cost budget
      state.cost_cents >= state.budgets.max_cost_cents ->
        {:stop, "Cost budget exceeded"}

      # Check deadline
      DateTime.compare(DateTime.utc_now(), state.budgets.deadline_at) == :gt ->
        {:stop, "Deadline exceeded"}

      # Check for looping
      Critic.looping?(state.steps) ->
        {:stop, "Detected looping behavior"}

      # Check policy
      state.policy && state.policy.stop_reason?(state) ->
        case state.policy.stop_reason?(state) do
          nil -> :continue
          {:done, reason} -> {:stop, reason}
        end

      true ->
        :continue
    end
  end

  defp process_think_phase(state) do
    start_time = System.monotonic_time(:millisecond)

    # Build messages for LLM
    messages = build_messages(state)

    # Get decision from LLM
    opts = %{
      service_config: state.service_config,
      temperature: 0.7,
      max_tokens: 2000
    }

    case LLMBridge.next_decision(messages, opts) do
      {:ok, decision} ->
        latency_ms = System.monotonic_time(:millisecond) - start_time

        # Validate decision
        case Decision.validate(decision) do
          :ok ->
            process_act_phase(state, decision, latency_ms)

          {:error, errors} ->
            Logger.error("Invalid decision: #{inspect(errors)}")
            error_state = %{state | status: :error}
            finalize_run(error_state, "Invalid decision from LLM")
        end

      {:error, reason} ->
        Logger.error("LLM error: #{inspect(reason)}")
        error_state = %{state | status: :error}
        finalize_run(error_state, "LLM error: #{inspect(reason)}")
    end
  end

  defp build_messages(state) do
    system_prompt = build_system_prompt(state)

    messages = [
      %{role: :system, content: system_prompt}
    ]

    # Add context summary if present
    messages =
      if state.context_summary != "" do
        messages ++ [%{role: :system, content: "Context: #{state.context_summary}"}]
      else
        messages
      end

    # Add short window messages
    messages ++ state.short_window
  end

  defp build_system_prompt(state) do
    tools_desc =
      ToolBroker.describe()
      |> Enum.map(fn tool -> "- #{tool.name}: #{tool.desc}" end)
      |> Enum.join("\n")

    """
    You are an AI agent working to achieve the following goal:
    #{state.goal}

    Current plan:
    #{Enum.join(state.plan, "\n")}

    Available tools:
    #{tools_desc}

    Steps completed: #{length(state.steps)}
    Budget remaining: #{state.budgets.max_steps - length(state.steps)} steps

    Respond with one of:
    - Use a tool: {"action": "tool", "name": "tool_name", "args": {...}}
    - Send a message: {"action": "message", "content": "..."}
    - Replan: {"action": "replan", "updated_plan": [...], "rationale": "..."}
    - Complete: {"action": "done", "rationale": "..."}
    """
  end

  defp process_act_phase(state, decision, latency_ms) do
    case decision.next_action do
      "tool" ->
        execute_tool_action(state, decision, latency_ms)

      "message" ->
        execute_message_action(state, decision, latency_ms)

      "replan" ->
        execute_replan_action(state, decision, latency_ms)

      "done" ->
        execute_done_action(state, decision, latency_ms)
    end
  end

  defp execute_tool_action(state, decision, _latency_ms) do
    call_id = generate_call_id()

    # Store inflight tool call
    tool_info = %{
      name: decision.tool_name,
      args: decision.arguments,
      started_at: DateTime.utc_now()
    }

    new_inflight = Map.put(state.inflight, call_id, tool_info)
    new_state = %{state | status: :awaiting_tool, inflight: new_inflight}

    # Execute tool asynchronously
    parent = self()

    Task.start(fn ->
      result = ToolBroker.call(decision.tool_name, decision.arguments, %{run_id: state.id})
      send(parent, {:tool_result, call_id, result})
    end)

    {:noreply, new_state}
  end

  defp execute_message_action(state, decision, latency_ms) do
    step = %Step{
      num: length(state.steps) + 1,
      action: %{type: "message", content: decision.assistant_message},
      observation: %{acknowledged: true},
      rationale_summary: decision.rationale_summary,
      latency_ms: latency_ms
    }

    new_state = update_state_with_step(state, step)

    new_state = %{
      new_state
      | short_window:
          new_state.short_window ++
            [
              %{role: :assistant, content: decision.assistant_message}
            ]
    }

    # Schedule next step
    Process.send_after(self(), :step, 100)
    {:noreply, new_state}
  end

  defp execute_replan_action(state, decision, latency_ms) do
    step = %Step{
      num: length(state.steps) + 1,
      action: %{type: "replan", new_plan: decision.updated_plan},
      observation: %{plan_updated: true},
      rationale_summary: decision.rationale_summary,
      latency_ms: latency_ms
    }

    new_state = update_state_with_step(state, step)
    new_state = %{new_state | plan: decision.updated_plan}

    # Persist updated plan
    Persistence.update_run(state.id, %{plan: %{steps: decision.updated_plan}})

    # Schedule next step
    Process.send_after(self(), :step, 100)
    {:noreply, new_state}
  end

  defp execute_done_action(state, decision, latency_ms) do
    step = %Step{
      num: length(state.steps) + 1,
      action: %{type: "done"},
      observation: %{completed: true},
      rationale_summary: decision.rationale_summary,
      latency_ms: latency_ms
    }

    new_state = update_state_with_step(state, step)
    finalize_run(new_state, decision.rationale_summary || "Task completed")
  end

  defp handle_tool_observation(state, tool_info, result) do
    {observation, tokens} =
      case result do
        {:ok, %{content: content, token_cost: cost}} ->
          # Ensure observation is always a map
          obs = if is_map(content), do: content, else: %{content: content}
          {obs, cost}

        {:error, error} ->
          {%{error: error}, 0}
      end

    step = %Step{
      num: length(state.steps) + 1,
      action: %{type: "tool", name: tool_info.name, args: tool_info.args},
      observation: observation,
      tokens_out: tokens
    }

    new_state = update_state_with_step(state, step)

    # Add tool result to short window in proper format
    tool_message = format_tool_result_message(tool_info, observation)
    %{new_state | short_window: new_state.short_window ++ [tool_message]}
  end

  defp update_state_with_step(state, step) do
    # Keep last 20 steps
    new_steps = [step | state.steps] |> Enum.take(20)

    # Update tokens and cost
    new_tokens = state.tokens_used + (step.tokens_in || 0) + (step.tokens_out || 0)
    new_cost = state.cost_cents + estimate_cost(step)

    # Update context summary if needed
    new_summary =
      if rem(length(new_steps), 5) == 0 do
        Summarizer.rollup(state.context_summary, step.observation)
      else
        state.context_summary
      end

    # Prune short window
    new_window = Summarizer.prune_window(state.short_window, 12)

    # Persist step (check for duplicates first)
    if Enum.any?(state.steps, fn s -> s.num == step.num end) do
      require Logger
      Logger.warning("Attempting to persist duplicate step #{step.num} for run #{state.id}, skipping")
    else
      case Persistence.append_step(%{
        run_id: state.id,
        step_num: step.num,
        phase: Atom.to_string(state.status),
        action: step.action,
        observation: step.observation,
        rationale_summary: step.rationale_summary,
        tokens_in: step.tokens_in,
        tokens_out: step.tokens_out,
        latency_ms: step.latency_ms
      }) do
        {:ok, _} -> :ok
        {:error, changeset} ->
          # Log the error but don't crash the agent
          require Logger
          Logger.warning("Failed to persist step #{step.num} for run #{state.id}: #{inspect(changeset.errors)}")
      end
    end

    # Broadcast step
    PubSub.broadcast_step(state.id, step)

    %{
      state
      | steps: new_steps,
        tokens_used: new_tokens,
        cost_cents: new_cost,
        context_summary: new_summary,
        short_window: new_window
    }
  end

  defp finalize_run(state, reason) do
    final_status = if state.status == :error, do: "error", else: "completed"

    Persistence.update_run(state.id, %{
      status: final_status,
      finished_at: DateTime.utc_now(),
      tokens_in: state.tokens_used,
      cost_cents: state.cost_cents
    })

    PubSub.broadcast_status(state.id, %{
      status: final_status,
      reason: reason,
      steps_completed: length(state.steps)
    })

    {:noreply, %{state | status: :done}}
  end

  defp generate_call_id do
    "call_" <> Ecto.UUID.generate()
  end

  defp estimate_cost(%Step{tokens_in: t_in, tokens_out: t_out}) do
    # Rough estimate: $0.01 per 1K tokens
    total_tokens = (t_in || 0) + (t_out || 0)
    # cents
    div(total_tokens, 100)
  end

  defp format_tool_result_message(tool_info, observation) do
    # Format tool result for LLM consumption - encode as JSON string for API
    content =
      case observation do
        content when is_binary(content) ->
          # If it's already a string, assume it's JSON and validate it
          case Jason.decode(content) do
            # Valid JSON string, keep as-is
            {:ok, _parsed} -> content
            # Not JSON, keep as plain string
            {:error, _} -> content
          end

        other ->
          # If it's not a string, encode it as JSON
          case Jason.encode(other) do
            {:ok, json_string} -> json_string
            {:error, _} -> inspect(other)
          end
      end

    %{role: :tool, content: content, tool_call_id: "call_#{tool_info.name}", name: tool_info.name}
  end

end
