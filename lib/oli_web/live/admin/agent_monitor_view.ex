defmodule OliWeb.Admin.AgentMonitorView do
  use OliWeb, :live_view

  alias Oli.GenAI.Agent
  alias Oli.GenAI.Agent.{PubSub, DemoPolicy}
  alias OliWeb.Common.Properties.Groups
  alias OliWeb.Common.Breadcrumb

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_, _session, socket) do
    author = socket.assigns.current_author

    {:ok,
     assign(socket,
       author: author,
       breadcrumbs: breadcrumb(),
       current_run_id: nil,
       messages: [],
       agent_status: :idle,
       policy_constraints: DemoPolicy.constraints(),
       policy_status: nil
     )}
  end

  def handle_event("start_agent", _params, socket) do
    # Start a new agent with a hardcoded goal
    run_id = Ecto.UUID.generate()

    service_config =
      Oli.Repo.get(Oli.GenAI.Completions.ServiceConfig, 1)
      |> Oli.Repo.preload(:primary_model)
      |> Oli.Repo.preload(:backup_model)

    goal = """
    Write a multiple choice question about birds in example_course project. Build a TODO list
    of steps to complete this task, then execute the steps one by one.

    Steps to complete this task:
    1. Understand the structure of a multiple choice question in OLI. (tools: example_activity, json_schema)
    2) Author a question stem, then a correct answer, then think hard to generate 2 or 3 useful distractors that likely represent common misconceptions.
    3) Author three hints, with the third hint being a "bottom out" hint which basically gives away the answer.
    4) Create a response and feedback for the correct answer and each of the distrctors.  IT IS IMPORTANT to also
    include one extra response as a "catch all" whose rule is "input like {.*}" with generic feedback of "Incorrect."
    5) Validate the JSON (tool: activity_validation)
    6) Create the activity (tool: create_activity)
    """

    args = %{
      goal: goal,
      run_id: run_id,
      service_config: service_config,
      policy: DemoPolicy
    }

    case Agent.start_run(args) do
      {:ok, _pid} ->
        # Subscribe to PubSub updates for this run
        Phoenix.PubSub.subscribe(Oli.PubSub, PubSub.topic(run_id))

        # Update socket state
        socket =
          socket
          |> assign(:current_run_id, run_id)
          |> assign(:agent_status, :running)
          |> add_message("Agent started with run ID: #{run_id}")

        {:noreply, socket}

      {:error, reason} ->
        socket = add_message(socket, "Failed to start agent: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_event("stop_agent", _params, socket) do
    case socket.assigns.current_run_id do
      nil ->
        socket = add_message(socket, "No agent currently running")
        {:noreply, socket}

      run_id ->
        Agent.cancel(run_id)

        socket =
          socket
          |> assign(:agent_status, :cancelled)
          |> add_message("Agent cancelled: #{run_id}")

        {:noreply, socket}
    end
  end

  def handle_event("clear_messages", _params, socket) do
    {:noreply, assign(socket, :messages, [])}
  end

  # Handle PubSub messages from the agent
  def handle_info({:agent_step, step}, socket) do
    message = format_step_message(step)
    socket = add_message(socket, message)
    {:noreply, socket}
  end

  def handle_info({:agent_status, status}, socket) do
    message = "Status: #{status.status} (#{status.reason || "no reason"})"

    socket =
      socket
      |> assign(:agent_status, status.status)
      |> add_message(message)
      |> maybe_update_policy_status()

    {:noreply, socket}
  end

  def handle_info({:agent_stats, stats}, socket) do
    message = "Stats: #{stats.tokens_used || 0} tokens, $#{stats.cost_cents || 0} cost"
    socket = add_message(socket, message)
    {:noreply, socket}
  end

  def handle_info({:agent_draft, draft}, socket) do
    message = "Draft: #{String.slice(draft.content || "empty", 0, 100)}..."
    socket = add_message(socket, message)
    {:noreply, socket}
  end

  # Add a timestamped message to the message list
  defp add_message(socket, content) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    new_message = %{timestamp: timestamp, content: content}
    # Keep only last 50 messages
    messages = [new_message | socket.assigns.messages] |> Enum.take(50)
    assign(socket, :messages, messages)
  end
  
  # Update policy status if we have an active run
  defp maybe_update_policy_status(socket) do
    case socket.assigns.current_run_id do
      nil -> socket
      run_id ->
        case Agent.info(run_id) do
          {:ok, info} ->
            policy_status = DemoPolicy.status(%{
              steps: info.last_step && [info.last_step] || [],
              tokens_used: info.tokens_used || 0,
              cost_cents: info.cost_cents || 0,
              start_time: DateTime.utc_now() |> DateTime.add(-5, :minute) # Rough estimate since we don't have exact start time
            })
            assign(socket, :policy_status, policy_status)
          {:error, _} -> socket
        end
    end
  end

  def render(assigns) do
    ~H"""
    <Groups.render>
      <div class="container mx-auto p-6">
        <div class="mb-6">
          <h1 class="text-3xl font-bold mb-2">Agent Monitor</h1>
          <p class="text-gray-600">Test and monitor AI Agent invocations</p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Control Panel -->
          <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-xl font-semibold mb-4">Agent Control</h2>

            <div class="space-y-4">
              <div class="flex items-center space-x-4">
                <span class="text-sm font-medium">Status:</span>
                <span class={[
                  "px-2 py-1 rounded text-sm font-medium",
                  status_class(@agent_status)
                ]}>
                  {format_status(@agent_status)}
                </span>
              </div>

              <div class="flex items-center space-x-4">
                <span class="text-sm font-medium">Current Run:</span>
                <span class="text-sm text-gray-600">
                  {@current_run_id || "None"}
                </span>
              </div>

              <div class="flex space-x-3">
                <button
                  phx-click="start_agent"
                  disabled={@agent_status == :running}
                  class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
                >
                  Start Agent
                </button>

                <button
                  phx-click="stop_agent"
                  disabled={@agent_status != :running}
                  class="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
                >
                  Stop Agent
                </button>

                <button
                  phx-click="clear_messages"
                  class="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700"
                >
                  Clear Messages
                </button>
              </div>

              <div class="bg-gray-50 p-3 rounded">
                <h3 class="text-sm font-medium mb-2">Current Task:</h3>
                <p class="text-sm text-gray-700">Write a multiple choice question about birds</p>
              </div>

              <!-- Policy Constraints -->
              <div class="bg-blue-50 p-3 rounded border border-blue-200">
                <h3 class="text-sm font-medium mb-2 text-blue-800">Policy Constraints</h3>
                <div class="space-y-1 text-xs text-blue-700">
                  <div>Max Steps: {@policy_constraints.max_steps}</div>
                  <div>Max Tokens: {number_format(@policy_constraints.max_tokens)}</div>
                  <div>Max Cost: ${@policy_constraints.max_cost_cents / 100}</div>
                  <div>Max Runtime: {@policy_constraints.max_runtime_minutes} min</div>
                  <%= if @policy_status do %>
                    <div class="mt-2 pt-2 border-t border-blue-300">
                      <div class="font-medium">Current Usage:</div>
                      <div>Steps: {@policy_status.steps_used}/{@policy_constraints.max_steps}</div>
                      <div>Tokens: {number_format(@policy_status.tokens_used)}</div>
                      <div>Cost: ${@policy_status.cost_used / 100}</div>
                      <div>Runtime: {@policy_status.runtime_minutes} min</div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

    <!-- Message Feed -->
          <div class="lg:col-span-2 bg-white shadow rounded-lg p-6">
            <h2 class="text-xl font-semibold mb-4">Live Messages (Debug View)</h2>

            <div class="space-y-2 max-h-96 overflow-y-auto">
              <%= if Enum.empty?(@messages) do %>
                <p class="text-gray-500 text-sm">No messages yet. Start an agent to see activity.</p>
              <% else %>
                <%= for message <- @messages do %>
                  <div class="border-l-2 border-blue-200 pl-3 py-2 mb-3">
                    <div class="text-xs text-gray-500 mb-1">
                      {message.timestamp}
                    </div>
                    <div class="text-sm font-mono whitespace-pre-line">
                      {message.content}
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Groups.render>
    """
  end

  defp status_class(:idle), do: "bg-gray-100 text-gray-800"
  defp status_class(:running), do: "bg-blue-100 text-blue-800"
  defp status_class(:thinking), do: "bg-yellow-100 text-yellow-800"
  defp status_class(:awaiting_tool), do: "bg-orange-100 text-orange-800"
  defp status_class(:done), do: "bg-green-100 text-green-800"
  defp status_class(:error), do: "bg-red-100 text-red-800"
  defp status_class(:cancelled), do: "bg-gray-100 text-gray-800"
  defp status_class(_), do: "bg-gray-100 text-gray-800"

  defp format_status(status) when is_atom(status),
    do: status |> to_string() |> String.capitalize()

  defp format_status(status), do: inspect(status)

  defp breadcrumb do
    [
      Breadcrumb.new(%{link: ~p"/admin", full_title: "Admin"}),
      Breadcrumb.new(%{full_title: "Agent Monitor"})
    ]
  end

  defp format_step_message(step) do
    # Build the main action line
    action_line = case step.action do
      %{type: "tool", name: name, args: args} ->
        args_summary = format_tool_args(args)
        "Step #{step.num}: 🔧 #{name}#{args_summary}"

      %{type: "message", content: content} ->
        preview = String.slice(content || "", 0, 80)
        preview = if String.length(content || "") > 80, do: preview <> "...", else: preview
        "Step #{step.num}: 💬 #{preview}"

      %{type: "replan", new_plan: plan} when is_list(plan) ->
        "Step #{step.num}: 📋 Replan (#{length(plan)} steps)"

      %{type: "done"} ->
        "Step #{step.num}: ✅ Completed"

      %{type: type} ->
        "Step #{step.num}: #{type}"

      _ ->
        "Step #{step.num}: Unknown action"
    end

    # Add performance metrics if available
    perf_info = build_performance_info(step)
    
    # Add observation info if available and relevant
    obs_info = build_observation_info(step)
    
    # Add rationale if available
    rationale_info = build_rationale_info(step)
    
    # Combine all parts
    parts = [action_line, perf_info, obs_info, rationale_info]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
    
    parts
  end

  defp format_tool_args(args) when is_map(args) do
    case Enum.take(args, 3) do
      [] ->
        ""

      small_args ->
        arg_strings =
          Enum.map(small_args, fn {key, value} ->
            formatted_value =
              case value do
                val when is_binary(val) and byte_size(val) > 30 ->
                  String.slice(val, 0, 30) <> "..."

                val ->
                  inspect(val) |> String.slice(0, 30)
              end

            "#{key}: #{formatted_value}"
          end)

        " (#{Enum.join(arg_strings, ", ")})"
    end
  end

  defp format_tool_args(_), do: ""
  
  defp number_format(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
  
  defp number_format(number), do: inspect(number)
  
  defp build_performance_info(step) do
    metrics = []
    
    metrics = if step.latency_ms do
      ["⏱️ #{step.latency_ms}ms" | metrics]
    else
      metrics
    end
    
    metrics = if step.tokens_in && step.tokens_in > 0 do
      ["📥 #{step.tokens_in} tokens in" | metrics]
    else
      metrics
    end
    
    metrics = if step.tokens_out && step.tokens_out > 0 do
      ["📤 #{step.tokens_out} tokens out" | metrics]
    else
      metrics
    end
    
    if Enum.empty?(metrics) do
      ""
    else
      "  └─ " <> Enum.join(metrics, " | ")
    end
  end
  
  defp build_observation_info(step) do
    case step.observation do
      nil -> ""
      obs when is_map(obs) ->
        case obs do
          %{error: error} ->
            "  ❌ Error: #{inspect(error)}"
          %{content: content} when is_binary(content) ->
            preview = String.slice(content, 0, 120)
            preview = if String.length(content) > 120, do: preview <> "...", else: preview
            "  ✅ Result: #{preview}"
          %{content: content} ->
            "  ✅ Result: #{inspect(content) |> String.slice(0, 100)}..."
          other ->
            formatted = inspect(other) |> String.slice(0, 100)
            formatted = if String.length(inspect(other)) > 100, do: formatted <> "...", else: formatted
            "  📊 Data: #{formatted}"
        end
      obs ->
        formatted = inspect(obs) |> String.slice(0, 100)
        formatted = if String.length(inspect(obs)) > 100, do: formatted <> "...", else: formatted
        "  📋 #{formatted}"
    end
  end
  
  defp build_rationale_info(step) do
    case step.rationale_summary do
      nil -> ""
      "" -> ""
      rationale ->
        preview = String.slice(rationale, 0, 150)
        preview = if String.length(rationale) > 150, do: preview <> "...", else: preview
        "  💭 Rationale: #{preview}"
    end
  end
end
