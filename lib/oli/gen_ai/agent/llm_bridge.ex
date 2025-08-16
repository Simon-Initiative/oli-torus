defmodule Oli.GenAI.Agent.LLMBridge do
  @moduledoc """
  Adapter from Agent messages/state to Oli.GenAI.Completions.* requests,
  including function-calling and model fallback via ServiceConfig.
  """

  require Logger
  alias Oli.GenAI.Agent.{ToolBroker, Decision}
  alias Oli.GenAI.Completions
  alias Oli.GenAI.Completions.{ServiceConfig, RegisteredModel, Message, Function}

  @type message :: %{role: :system | :user | :assistant | :tool, content: term()}
  @type opts :: %{
          required(:service_config) => ServiceConfig.t(),
          optional(:temperature) => number(),
          optional(:max_tokens) => pos_integer()
        }

  @doc """
  Calls the primary model with tools; on provider/tool errors, applies fallback strategy
  from ServiceConfig. Returns a normalized Decision.
  """
  @spec next_decision([message], opts) :: {:ok, Decision.t()} | {:error, term}
  def next_decision(messages, opts) do
    config = Map.fetch!(opts, :service_config)

    with {:ok, primary, fallbacks} <- select_models(config),
         {:ok, response} <- call_provider_with_fallback(primary, fallbacks, messages, opts) do
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
    {:ok, primary, fallbacks} |> IO.inspect(label: "Selected Models")
  end

  def select_models(%ServiceConfig{}) do
    {:error, "ServiceConfig missing primary model"}
  end

  def select_models(_invalid) do
    {:error, "Invalid service config"}
  end

  @doc """
  Builds the provider-specific request using tools from ToolBroker.tools_for_completion/0
  and the messages. Returns a provider-agnostic completion payload.
  """
  @spec call_provider(RegisteredModel.t(), [message], map) :: {:ok, map()} | {:error, term}
  def call_provider(%RegisteredModel{} = model, messages, opts) when is_map(opts) do
    try do
      # Convert internal message format to Completions.Message format
      completion_messages = convert_messages_to_completion_format(messages)

      # Convert tools to Completions.Function format
      tools = ToolBroker.tools_for_completion()
      completion_functions = convert_tools_to_completion_functions(tools)

      # Use the Completions module for the actual call
      case Completions.generate(completion_messages, completion_functions, model) do
        {:ok, response} ->
          {:ok, response}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("LLM call failed: #{Exception.message(e)}")
        {:error, Exception.message(e)}
    end
  end

  defp call_provider_with_fallback(primary, fallbacks, messages, opts) do
    case call_provider(primary, messages, opts) do
      {:ok, response} ->
        {:ok, response}

      {:error, _reason} ->
        # Try fallbacks
        try_fallbacks(fallbacks, messages, opts)
    end
  end

  defp try_fallbacks([], _messages, _opts) do
    {:error, "All models failed"}
  end

  defp try_fallbacks([model | rest], messages, opts) do
    case call_provider(model, messages, opts) do
      {:ok, response} ->
        {:ok, response}

      {:error, _reason} ->
        try_fallbacks(rest, messages, opts)
    end
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
