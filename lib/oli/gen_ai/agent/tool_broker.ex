defmodule Oli.GenAI.Agent.ToolBroker do
  @moduledoc """
  Tool broker that invokes MCP/local tools and exposes:
    - registry for prompting (describe/0)
    - function specs for completions (tools_for_completion/0)
  """
  @behaviour Oli.GenAI.Agent.Tool
  use GenServer
  require Logger

  alias Oli.GenAI.Agent.MCPToolRegistry

  @type tool_spec :: %{name: String.t(), desc: String.t(), schema: map()}
  @type ctx :: map()

  # Client API

  @spec start_link(keyword) :: {:ok, pid} | {:error, term}
  def start_link(opts \\ []) do
    case GenServer.start_link(__MODULE__, opts, name: __MODULE__) do
      {:ok, _pid} = result ->
        # Register some default tools
        register_default_tools()
        result

      error ->
        error
    end
  end

  @spec start(keyword) :: :ok | {:error, term}
  def start(opts \\ []) do
    case start_link(opts) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  @spec register(tool_spec) :: :ok | {:error, term}
  def register(spec) do
    case validate_tool_spec(spec) do
      :ok ->
        GenServer.call(__MODULE__, {:register, spec})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec list() :: [String.t()]
  def list do
    case GenServer.whereis(__MODULE__) do
      nil -> []
      _pid -> GenServer.call(__MODULE__, :list)
    end
  end

  @spec describe() :: [tool_spec]
  def describe do
    case GenServer.whereis(__MODULE__) do
      nil -> []
      _pid -> GenServer.call(__MODULE__, :describe)
    end
  end

  @doc """
  Returns function/tool specs suitable for the Completions layer.
  For OpenAI, return [%{type: "function", function: %{name, description, parameters}}]
  For Anthropic, return [%{name, description, input_schema}]
  The LLMBridge will adapt this as needed per provider.
  """
  @spec tools_for_completion() :: list()
  def tools_for_completion do
    case GenServer.whereis(__MODULE__) do
      nil -> []
      _pid -> GenServer.call(__MODULE__, :tools_for_completion)
    end
  end

  @impl true
  def call(name, args, ctx) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        {:error, "ToolBroker not initialized"}

      _pid ->
        GenServer.call(__MODULE__, {:call_tool, name, args, ctx}, 30_000)
    end
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{tools: %{}}}
  end

  @impl true
  def handle_call({:register, spec}, _from, state) do
    name = Map.get(spec, :name)

    case Map.has_key?(state.tools, name) do
      true ->
        {:reply, {:error, "Tool '#{name}' already registered"}, state}

      false ->
        new_tools = Map.put(state.tools, name, spec)
        {:reply, :ok, %{state | tools: new_tools}}
    end
  end

  def handle_call(:list, _from, state) do
    names = Map.keys(state.tools)
    {:reply, names, state}
  end

  def handle_call(:describe, _from, state) do
    descriptions = Map.values(state.tools)
    {:reply, descriptions, state}
  end

  def handle_call(:tools_for_completion, _from, state) do
    specs =
      Enum.map(state.tools, fn {_name, spec} ->
        to_openai_function_spec(spec)
      end)

    {:reply, specs, state}
  end

  def handle_call({:call_tool, name, args, ctx}, _from, state) do
    case Map.get(state.tools, name) do
      nil ->
        {:reply, {:error, "Unknown tool: #{name}"}, state}

      tool_spec ->
        case validate_tool_args(tool_spec, args) do
          :ok ->
            result = execute_tool(name, args, ctx)
            {:reply, result, state}

          {:error, reason} ->
            {:reply, {:error, "Validation error: #{reason}"}, state}
        end
    end
  end

  # Private functions

  defp validate_tool_spec(%{name: name, desc: desc, schema: schema})
       when is_binary(name) and is_binary(desc) and is_map(schema) do
    :ok
  end

  defp validate_tool_spec(_) do
    {:error, "Tool spec must have :name (string), :desc (string), and :schema (map)"}
  end

  defp validate_tool_args(tool_spec, args) do
    schema = Map.get(tool_spec, :schema, %{})
    required = get_in(schema, ["required"]) || []

    # Check required arguments
    missing = Enum.filter(required, fn req -> not Map.has_key?(args, req) end)

    if missing == [] do
      :ok
    else
      {:error, "Missing required argument: #{Enum.join(missing, ", ")}"}
    end
  end

  defp to_openai_function_spec(tool_spec) do
    %{
      type: "function",
      function: %{
        name: Map.get(tool_spec, :name),
        description: Map.get(tool_spec, :desc),
        parameters: Map.get(tool_spec, :schema, %{})
      }
    }
  end

  defp execute_tool(name, args, ctx) do
    # All tools are now routed through the MCP registry
    MCPToolRegistry.execute_mcp_tool(name, args, ctx)
  end

  defp register_default_tools do
    # Register all MCP tools dynamically
    mcp_tools = MCPToolRegistry.get_all_tools()

    Enum.each(mcp_tools, fn tool ->
      case register(tool) do
        :ok -> :ok
        {:error, reason} -> Logger.warning("Failed to register MCP tool #{tool.name}: #{reason}")
      end
    end)
  end
end
