defmodule Oli.GenAI.Agent.Decision do
  @moduledoc """
  Structured next action. Includes helpers to decode provider-specific function-calling
  outputs from Oli.GenAI.Completions into a normalized decision.
  """

  @typedoc "One of: 'tool' | 'message' | 'replan' | 'done'"
  @type kind :: String.t()

  @type t :: %__MODULE__{
          next_action: kind,
          tool_name: String.t() | nil,
          arguments: map | nil,
          assistant_message: String.t() | nil,
          updated_plan: [String.t()] | nil,
          rationale_summary: String.t() | nil
        }

  defstruct [:next_action, :tool_name, :arguments, :assistant_message, :updated_plan, :rationale_summary]

  @valid_actions ~w(tool message replan done)

  @spec new(map) :: t
  def new(map) do
    struct(__MODULE__, map)
  end

  @spec validate(t) :: :ok | {:error, [String.t()]}
  def validate(%__MODULE__{next_action: action} = d) do
    errors = []

    errors =
      if action in @valid_actions do
        errors
      else
        ["invalid action type: #{action}" | errors]
      end

    IO.inspect(action)
    IO.inspect(d)

    errors =
      case action do
        "tool" ->
          if is_nil(d.tool_name) do
            ["tool_name is required for tool action" | errors]
          else
            errors
          end

        "message" ->
          if is_nil(d.assistant_message) do
            ["assistant_message is required for message action" | errors]
          else
            errors
          end

        "replan" ->
          if is_nil(d.updated_plan) do
            ["updated_plan is required for replan action" | errors]
          else
            errors
          end

        _ ->
          errors
      end

    if errors == [] do
      :ok
    else
      {:error, Enum.reverse(errors)}
    end
  end

  @spec from_completion(map) :: {:ok, t} | {:error, term}
  def from_completion(provider_payload) do
    try do
      decision = parse_provider_response(provider_payload)
      {:ok, decision}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp parse_provider_response(payload) do
    cond do
      # OpenAI-style response
      openai_response?(payload) ->
        parse_openai(payload)

      # Anthropic-style response
      anthropic_response?(payload) ->
        parse_anthropic(payload)

      # Structured JSON response in content
      structured_response?(payload) ->
        parse_structured(payload)

      true ->
        raise "Unknown provider response format"
    end
  end

  defp openai_response?(payload) do
    Map.has_key?(payload, "choices")
  end

  defp anthropic_response?(payload) do
    Map.has_key?(payload, "content") and Map.has_key?(payload, "role")
  end

  defp structured_response?(payload) do
    case get_in(payload, ["choices", Access.at(0), "message", "content"]) do
      nil -> false
      content when is_binary(content) -> String.starts_with?(String.trim(content), "{")
      _ -> false
    end
  end

  defp parse_openai(payload) do
    message = get_in(payload, ["choices", Access.at(0), "message"])

    cond do
      # Tool call
      tool_calls = Map.get(message, "tool_calls") ->
        tool_call = List.first(tool_calls)
        function = Map.get(tool_call, "function", %{})

        %__MODULE__{
          next_action: "tool",
          tool_name: Map.get(function, "name"),
          arguments: parse_arguments(Map.get(function, "arguments"))
        }

      # Structured JSON in content
      content = Map.get(message, "content") ->
        if String.starts_with?(String.trim(content || ""), "{") do
          parse_json_content(content)
        else
          %__MODULE__{
            next_action: "message",
            assistant_message: content
          }
        end

      true ->
        %__MODULE__{
          next_action: "message",
          assistant_message: Map.get(message, "content")
        }
    end
  end

  defp parse_anthropic(payload) do
    content = Map.get(payload, "content", [])

    case List.first(content) do
      %{"type" => "tool_use", "name" => name, "input" => input} ->
        %__MODULE__{
          next_action: "tool",
          tool_name: name,
          arguments: input
        }

      _ ->
        # Try to extract text content
        text = extract_anthropic_text(content)
        %__MODULE__{
          next_action: "message",
          assistant_message: text
        }
    end
  end

  defp parse_structured(payload) do
    content = get_in(payload, ["choices", Access.at(0), "message", "content"])
    parse_json_content(content)
  end

  defp parse_json_content(content) when is_binary(content) do
    case Jason.decode(content) do
      {:ok, json} ->
        case Map.get(json, "action") do
          "replan" ->
            %__MODULE__{
              next_action: "replan",
              updated_plan: Map.get(json, "updated_plan"),
              rationale_summary: Map.get(json, "rationale")
            }

          "done" ->
            %__MODULE__{
              next_action: "done",
              rationale_summary: Map.get(json, "rationale")
            }

          _ ->
            %__MODULE__{
              next_action: "message",
              assistant_message: content
            }
        end

      {:error, _} ->
        %__MODULE__{
          next_action: "message",
          assistant_message: content
        }
    end
  end

  defp parse_arguments(args) when is_binary(args) do
    case Jason.decode(args) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{}
    end
  end

  defp parse_arguments(args) when is_map(args), do: args
  defp parse_arguments(_), do: %{}

  defp extract_anthropic_text(content) when is_list(content) do
    Enum.find_value(content, "", fn
      %{"type" => "text", "text" => text} -> text
      _ -> nil
    end)
  end

  defp extract_anthropic_text(_), do: ""

  @spec tool?(t) :: boolean
  def tool?(%__MODULE__{next_action: "tool"}), do: true
  def tool?(_), do: false

  @spec message?(t) :: boolean
  def message?(%__MODULE__{next_action: "message"}), do: true
  def message?(_), do: false

  @spec done?(t) :: boolean
  def done?(%__MODULE__{next_action: "done"}), do: true
  def done?(_), do: false
end
