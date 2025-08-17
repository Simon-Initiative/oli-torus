defmodule Oli.GenAI.Agent.DemoPolicy do
  @moduledoc """
  Demo policy for agent monitor with hardcoded constraints.
  Demonstrates policy functionality with conservative limits.
  """
  
  @behaviour Oli.GenAI.Agent.Policy
  
  # Conservative limits for demo purposes
  @max_steps 15
  @max_tokens 50_000
  @max_cost_cents 500
  @max_runtime_minutes 10
  
  # Disallowed tools for safety
  @restricted_tools ["dangerous_tool", "delete_file", "execute_shell"]
  
  @impl true
  def allowed_action?(%{tool_name: tool_name}, _state) when tool_name in @restricted_tools do
    {false, "Tool '#{tool_name}' is restricted by demo policy"}
  end
  
  def allowed_action?(%{tool_name: tool_name}, %{steps: steps}) when length(steps) > 10 do
    # Be more restrictive with tools after 10 steps
    if tool_name in ["create_activity", "push_files", "merge_pull_request"] do
      {false, "Tool '#{tool_name}' restricted after 10 steps to prevent unintended changes"}
    else
      true
    end
  end
  
  def allowed_action?(_decision, _state), do: true
  
  @impl true
  def stop_reason?(%{steps: steps}) when length(steps) >= @max_steps do
    {:done, "Demo policy step limit reached (#{@max_steps} steps)"}
  end
  
  def stop_reason?(%{tokens_used: tokens}) when tokens >= @max_tokens do
    {:done, "Demo policy token limit reached (#{@max_tokens} tokens)"}
  end
  
  def stop_reason?(%{cost_cents: cost}) when cost >= @max_cost_cents do
    {:done, "Demo policy cost limit reached ($#{@max_cost_cents/100})"}
  end
  
  def stop_reason?(%{start_time: start_time}) do
    runtime_minutes = DateTime.diff(DateTime.utc_now(), start_time, :minute)
    if runtime_minutes >= @max_runtime_minutes do
      {:done, "Demo policy runtime limit reached (#{@max_runtime_minutes} minutes)"}
    else
      nil
    end
  end
  
  def stop_reason?(_state), do: nil
  
  @impl true
  def redact(log_payload) do
    # Remove sensitive fields from logs
    Map.drop(log_payload, [:api_key, :secret, :password, :token])
  end
  
  # Helper functions for UI display
  def constraints do
    %{
      max_steps: @max_steps,
      max_tokens: @max_tokens,
      max_cost_cents: @max_cost_cents,
      max_runtime_minutes: @max_runtime_minutes,
      restricted_tools: @restricted_tools
    }
  end
  
  def status(%{steps: steps, tokens_used: tokens, cost_cents: cost, start_time: start_time}) do
    runtime_minutes = DateTime.diff(DateTime.utc_now(), start_time, :minute)
    
    %{
      steps_used: length(steps),
      steps_remaining: max(0, @max_steps - length(steps)),
      tokens_used: tokens,
      tokens_remaining: max(0, @max_tokens - tokens),
      cost_used: cost,
      cost_remaining: max(0, @max_cost_cents - cost),
      runtime_minutes: runtime_minutes,
      runtime_remaining: max(0, @max_runtime_minutes - runtime_minutes)
    }
  end
end