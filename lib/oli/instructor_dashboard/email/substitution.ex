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
  @token_pairs Enum.zip(@whitelist, @tokens)
  @token_regex ~r/\{[a-zA-Z_]+\}/

  @typedoc """
  Map from whitelist key (without braces) to its resolved value. Values may
  be `nil` for recipients with missing data; the validator is responsible
  for catching that case before `apply/2` runs.
  """
  @type values :: %{required(String.t()) => String.t() | nil}

  @doc "Returns the bare whitelist keys (no braces)."
  @spec whitelist() :: [String.t()]
  def whitelist, do: @whitelist

  @doc "Returns whitelisted tokens with braces (`{first_name}`, etc.)."
  @spec tokens() :: [String.t()]
  def tokens, do: @tokens

  @doc """
  Replaces every whitelisted token in `template` with its value from `values`.

  Returns `{:ok, substituted_string}` when every token used by `template`
  has a binary value. Returns `{:error, [{:nil_value, token}, ...]}` when
  one or more tokens used by `template` have a nil value — surfaces every
  nil-token in one shot so the caller can show all problems at once.

  `values` must contain every whitelist key (raises `KeyError` on missing
  keys — that's a programmer-error contract).

  Non-whitelisted tokens pass through unchanged.

  ## Examples

      iex> Oli.InstructorDashboard.Email.Substitution.apply(
      ...>   "Hi {first_name}, your progress in {course_name}",
      ...>   %{
      ...>     "first_name" => "Alice",
      ...>     "student_name" => "Alice Lee",
      ...>     "course_name" => "Calculus 101",
      ...>     "instructor_name" => "Dr. Sage"
      ...>   }
      ...> )
      {:ok, "Hi Alice, your progress in Calculus 101"}

  A nil value for a token that appears in the template surfaces as an
  `{:error, ...}` so the caller can collect actionable feedback:

      iex> Oli.InstructorDashboard.Email.Substitution.apply(
      ...>   "Hi {first_name}",
      ...>   %{
      ...>     "first_name" => nil,
      ...>     "student_name" => "Alice Lee",
      ...>     "course_name" => "Calculus 101",
      ...>     "instructor_name" => "Dr. Sage"
      ...>   }
      ...> )
      {:error, [{:nil_value, "{first_name}"}]}

  """
  @spec apply(String.t(), values()) :: {:ok, String.t()} | {:error, [{:nil_value, String.t()}]}
  def apply(template, %{} = values) when is_binary(template) do
    {result, errors} =
      Enum.reduce(@token_pairs, {template, []}, fn {name, token}, {acc, errs} ->
        case do_replace(String.contains?(acc, token), acc, token, Map.fetch!(values, name)) do
          {:ok, new_acc} -> {new_acc, errs}
          {:error, reason} -> {acc, [reason | errs]}
        end
      end)

    case errors do
      [] -> {:ok, result}
      errs -> {:error, Enum.reverse(errs)}
    end
  end

  defp do_replace(false, template, _token, _value), do: {:ok, template}

  defp do_replace(true, template, token, value) when is_binary(value),
    do: {:ok, String.replace(template, token, value)}

  defp do_replace(true, _template, token, nil), do: {:error, {:nil_value, token}}

  @doc "Returns tokens present in `template` that are NOT in the whitelist."
  @spec unsupported_tokens(String.t()) :: [String.t()]
  def unsupported_tokens(template) when is_binary(template) do
    @token_regex
    |> Regex.scan(template)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.reject(&(&1 in @tokens))
  end

  @doc "Returns whitelisted tokens that appear in `template`."
  @spec used_tokens(String.t()) :: [String.t()]
  def used_tokens(template) when is_binary(template) do
    Enum.filter(@tokens, &String.contains?(template, &1))
  end
end
