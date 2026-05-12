defmodule Oli.InstructorDashboard.Email.Substitution do
  @moduledoc """
  Whitelist-only placeholder substitution for instructor email templates.
  Pure string operations; no template evaluation.

  Whitelist: `{first_name}`, `{student_name}`, `{instructor_name}`,
  `{course_name}` — must stay in sync with `PromptComposer`
  `@supported_placeholders`.
  """

  @whitelist ~w(first_name student_name instructor_name course_name)
  @tokens Enum.map(@whitelist, &"{#{&1}}")
  @token_regex ~r/\{[a-zA-Z_]+\}/

  @typedoc "Map from whitelist key (without braces) to its resolved string value."
  @type values :: %{required(String.t()) => String.t()}

  @doc "Returns the bare whitelist keys (no braces)."
  @spec whitelist() :: [String.t()]
  def whitelist, do: @whitelist

  @doc "Returns whitelisted tokens with braces (`{first_name}`, etc.)."
  @spec tokens() :: [String.t()]
  def tokens, do: @tokens

  @doc """
  Replaces every whitelisted token in `string` with its value from `values`.

  `values` must contain every whitelist key with a binary value; raises
  `KeyError` on missing keys or `ArgumentError` on nil values (validator's
  responsibility to prevent). Non-whitelisted tokens pass through unchanged.
  """
  @spec apply(String.t(), values()) :: String.t()
  def apply(string, %{} = values) when is_binary(string) do
    Enum.reduce(@whitelist, string, fn name, acc ->
      case Map.fetch!(values, name) do
        value when is_binary(value) ->
          String.replace(acc, "{#{name}}", value)

        nil ->
          raise ArgumentError,
                "Substitution.apply/2: nil value for token {#{name}}. " <>
                  "Validator must catch unresolvable tokens BEFORE substitution runs."
      end
    end)
  end

  @doc "Returns tokens present in `string` that are NOT in the whitelist."
  @spec unsupported_tokens(String.t()) :: [String.t()]
  def unsupported_tokens(string) when is_binary(string) do
    @token_regex
    |> Regex.scan(string)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.reject(&(&1 in @tokens))
  end

  @doc "Returns whitelisted tokens that appear in `string`."
  @spec used_tokens(String.t()) :: [String.t()]
  def used_tokens(string) when is_binary(string) do
    Enum.filter(@tokens, &String.contains?(string, &1))
  end
end
