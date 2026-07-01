defmodule Oli.InstructorDashboard.Email.ContextBuilder do
  @moduledoc """
  Service boundary for assembling a normalized `EmailContext` from raw
  data gathered by an entry point (e.g., a tile or student-list LiveView).

  The builder is pure: it does NOT read from the database. Callers gather the
  required inputs (recipient roster, projection metadata, course/section
  context) and pass them in. This keeps the builder testable without a sandbox
  and reusable across entry points.

  See `docs/exec-plans/current/epics/intelligent_dashboard/email_sending/plan.md`
  Phase 1 step 1.2 for scope.
  """

  alias Oli.InstructorDashboard.Email.{EmailContext, Situation}

  @default_tone :neutral
  @valid_tones [:neutral, :encouraging, :firm]
  @required_recipient_keys [:student_id, :email, :given_name, :family_name]
  @strict_value_keys [:student_id, :email]

  @type input :: %{
          required(:section_id) => pos_integer(),
          required(:course_title) => String.t(),
          required(:instructor_name) => String.t(),
          required(:scope_label) => String.t(),
          required(:situation_key) => Situation.t(),
          required(:recipients) => [map()],
          optional(:instructor_email) => String.t() | nil,
          optional(:assessment) => map() | nil,
          optional(:objective) => map() | nil,
          optional(:content_item) => map() | nil,
          optional(:support_bucket) => map() | nil,
          optional(:tone) => EmailContext.tone()
        }

  @type error_reason ::
          :missing_section_id
          | :missing_course_title
          | :missing_instructor_name
          | :missing_scope_label
          | :missing_situation_key
          | :invalid_situation_key
          | :missing_recipients
          | :empty_recipients
          | {:invalid_recipient, integer(), atom()}
          | :invalid_tone

  @doc """
  Builds an `%EmailContext{}` from the input map.

  Returns `{:ok, EmailContext.t()}` on success or `{:error, error_reason()}`
  on validation failure.
  """
  @spec build(input()) :: {:ok, EmailContext.t()} | {:error, error_reason()}
  def build(input) when is_map(input) do
    with {:ok, section_id} <- fetch_required(input, :section_id, :missing_section_id),
         {:ok, course_title} <- fetch_required(input, :course_title, :missing_course_title),
         {:ok, instructor_name} <-
           fetch_required(input, :instructor_name, :missing_instructor_name),
         {:ok, scope_label} <- fetch_required(input, :scope_label, :missing_scope_label),
         {:ok, situation_key} <- validate_situation(input),
         {:ok, recipients} <- validate_recipients(input),
         {:ok, tone} <- validate_tone(input) do
      {:ok,
       %EmailContext{
         section_id: section_id,
         course_title: course_title,
         instructor_name: instructor_name,
         section_slug: Map.get(input, :section_slug),
         instructor_email: Map.get(input, :instructor_email),
         scope_label: scope_label,
         situation_key: situation_key,
         recipients: recipients,
         tone: tone,
         recipient_count: length(recipients),
         assessment: Map.get(input, :assessment),
         objective: Map.get(input, :objective),
         content_item: Map.get(input, :content_item),
         support_bucket: Map.get(input, :support_bucket)
       }}
    end
  end

  defp fetch_required(input, key, error) do
    case Map.get(input, key) do
      nil -> {:error, error}
      "" -> {:error, error}
      value -> {:ok, value}
    end
  end

  defp validate_situation(input) do
    case Map.get(input, :situation_key) do
      nil ->
        {:error, :missing_situation_key}

      key ->
        if Situation.valid?(key), do: {:ok, key}, else: {:error, :invalid_situation_key}
    end
  end

  defp validate_recipients(input) do
    case Map.get(input, :recipients) do
      nil ->
        {:error, :missing_recipients}

      [] ->
        {:error, :empty_recipients}

      recipients when is_list(recipients) ->
        recipients
        |> Enum.with_index()
        |> Enum.reduce_while({:ok, []}, fn {recipient, index}, {:ok, acc} ->
          case validate_recipient(recipient, index) do
            :ok -> {:cont, {:ok, [recipient | acc]}}
            {:error, _} = error -> {:halt, error}
          end
        end)
        |> case do
          {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
          error -> error
        end

      _other ->
        {:error, :missing_recipients}
    end
  end

  defp validate_recipient(recipient, index) when is_map(recipient) do
    Enum.find_value(@required_recipient_keys, :ok, fn key ->
      cond do
        not Map.has_key?(recipient, key) ->
          {:error, {:invalid_recipient, index, key}}

        key in @strict_value_keys and Map.get(recipient, key) in [nil, ""] ->
          {:error, {:invalid_recipient, index, key}}

        true ->
          false
      end
    end)
  end

  defp validate_recipient(_, index), do: {:error, {:invalid_recipient, index, :not_a_map}}

  defp validate_tone(input) do
    case Map.get(input, :tone, @default_tone) do
      tone when tone in @valid_tones -> {:ok, tone}
      _ -> {:error, :invalid_tone}
    end
  end
end
