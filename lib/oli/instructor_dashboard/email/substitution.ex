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

  @whitelist_token_regex ~r/\{(first_name|student_name|instructor_name|course_name)\}/

  # Broad pattern — catches AI typos so they don't slip through as plain text.
  @any_token_regex ~r/\{[^{}]+\}/

  # AI sometimes emits square-bracket placeholders like `[Your Name]` or
  # `[instructor's name]`. Negative lookahead excludes markdown link labels
  # `[label](url)` so those pass through to `sanitize_links/1` normally.
  @bracket_placeholder_regex ~r/\[[^\[\]\n]+\](?!\()/

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
    used_names =
      @whitelist_token_regex
      |> Regex.scan(template, capture: :all_but_first)
      |> List.flatten()
      |> Enum.uniq()

    nil_value_errors =
      used_names
      |> Enum.filter(fn name -> is_nil(Map.fetch!(values, name)) end)
      |> Enum.map(fn name -> {:nil_value, "{#{name}}"} end)

    if nil_value_errors == [] do
      # Single-pass on the original template — values are literals, not re-scanned.
      result =
        Regex.replace(@whitelist_token_regex, template, fn _full, name ->
          Map.fetch!(values, name)
        end)

      {:ok, result}
    else
      {:error, nil_value_errors}
    end
  end

  @doc """
  Returns tokens present in `template` that are NOT in the whitelist.

  Detects broad brace-delimited patterns (`{first-name}`, `{firstName}`,
  `{first_name1}`, `{First Name}`, `{nickname}`, …) so AI typos and
  unknown placeholders cannot slip through to recipients as plain text.

  Also detects square-bracket placeholders (`[Your Name]`,
  `[instructor's name]`, …) since the AI occasionally falls back to that
  convention from its training prior. Markdown link labels (`[label](url)`)
  are excluded via a negative lookahead so valid internal links still pass
  through `LinkValidator`.
  """
  @spec unsupported_tokens(String.t()) :: [String.t()]
  def unsupported_tokens(template) when is_binary(template) do
    brace_tokens =
      @any_token_regex
      |> Regex.scan(template)
      |> List.flatten()
      |> Enum.reject(&(&1 in @tokens))

    bracket_tokens =
      @bracket_placeholder_regex
      |> Regex.scan(template)
      |> List.flatten()

    (brace_tokens ++ bracket_tokens) |> Enum.uniq()
  end

  @doc "Returns whitelisted tokens that appear in `template`."
  @spec used_tokens(String.t()) :: [String.t()]
  def used_tokens(template) when is_binary(template) do
    Enum.filter(@tokens, &String.contains?(template, &1))
  end
end
