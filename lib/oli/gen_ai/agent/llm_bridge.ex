defmodule Oli.GenAI.Agent.LLMBridge do
  @moduledoc """
  Adapter from Agent messages/state to Oli.GenAI.Completions.* requests,
  including function-calling and model fallback via ServiceConfig.
  """

  require Logger
  alias Oli.GenAI.Agent.{ToolBroker, Decision}
  alias Oli.GenAI.Completions.{ServiceConfig, RegisteredModel, Message, Function}
  alias Oli.GenAI.Execution

  @type message :: %{role: :system | :user | :assistant | :tool, content: term()}
  @type completion_opts :: [
          temperature: number(),
          max_tokens: pos_integer(),
          section_id: integer() | nil,
          actor_id: integer() | nil
        ]

  @doc """
  Calls the primary model with tools; on provider/tool errors, applies fallback strategy
  from ServiceConfig. Returns a normalized Decision.
  """
  @spec next_decision([message], ServiceConfig.t(), completion_opts) ::
          {:ok, Decision.t()} | {:error, term}
  def next_decision(messages, %ServiceConfig{} = config, opts \\ []) do
    with {:ok, _primary, _fallbacks} <- select_models(config),
         {:ok, response} <- call_with_routing(config, messages, opts) do
      Decision.from_completion(response)
    else
      {:error, reason} ->
        Logger.error("LLM Bridge error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Selects the active RegisteredModel(s) from ServiceConfig for this Agent service."
  @spec select_models(ServiceConfig.t()) ::
          {:ok, RegisteredModel.t(), [RegisteredModel.t()]} | {:error, term}
  def select_models(%ServiceConfig{primary_model: primary, backup_model: backup})
      when not is_nil(primary) do
    fallbacks = if backup, do: [backup], else: []
    {:ok, primary, fallbacks}
  end

  def select_models(%ServiceConfig{}) do
    {:error, "ServiceConfig missing primary model"}
  end

  def select_models(_invalid) do
    {:error, "Invalid service config"}
  end

  defp call_with_routing(%ServiceConfig{} = config, messages, opts) do
    completion_messages = convert_messages_to_completion_format(messages)
    tools = ToolBroker.tools_for_completion()
    completion_functions = convert_tools_to_completion_functions(tools)

    request_ctx = %{
      request_type: :generate,
      feature: :agent,
      section_id: Keyword.get(opts, :section_id),
      actor_id: Keyword.get(opts, :actor_id),
      service_config_id: config.id
    }

    provider_opts = Keyword.take(opts, [:temperature, :max_tokens])

    Execution.generate(request_ctx, completion_messages, completion_functions, config,
      provider_opts: provider_opts
    )
  end

  defp convert_messages_to_completion_format(messages) do
    Enum.map(messages, fn msg ->
      role = Map.get(msg, :role, :user)
      content = Map.get(msg, :content, "")
      name = Map.get(msg, :name)

      case role do
        :system ->
          Message.new("system", to_string(content))

        :user ->
          Message.new("user", to_string(content))

        :assistant ->
          Message.new("assistant", to_string(content))

        :tool ->
          if name do
            Message.new("tool", to_string(content), name)
          else
            Message.new("tool", to_string(content))
          end

        _ ->
          Message.new("user", to_string(content))
      end
    end)
  end

  defp convert_tools_to_completion_functions(tools) do
    Enum.map(tools, fn tool ->
      # Convert from ToolBroker format to Completions.Function format
      case tool do
        %{type: "function", function: %{name: name, description: desc, parameters: params}} ->
          Function.new(name, desc, params)

        %{name: name, description: desc, input_schema: schema} ->
          Function.new(name, desc, schema)

        _ ->
          # Skip invalid tool format
          nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end
end
