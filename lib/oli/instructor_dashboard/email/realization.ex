defmodule Oli.InstructorDashboard.Email.Realization do
  @moduledoc """
  Per-recipient template realization. Pure function over rendered template
  strings; runs `Substitution` per recipient against a values map derived
  from the `EmailContext` recipient and instructor/course metadata.
  """

  alias Oli.InstructorDashboard.Email.{EmailContext, Substitution}

  @type template :: %{
          required(:subject) => String.t(),
          required(:html_body) => String.t(),
          required(:text_body) => String.t()
        }

  @type realized :: %{
          user_id: pos_integer(),
          email: String.t(),
          subject: String.t(),
          html_body: String.t(),
          text_body: String.t()
        }

  @type reason :: {:realize_failed, recipient_email :: String.t(), token :: String.t()}

  @doc """
  Realizes the template into concrete per-recipient strings.

  Validator should run first. If a recipient's data has changed since
  validation (race condition) or the validator has a gap, each affected
  recipient surfaces as `{:realize_failed, email, token}` so the caller
  can show actionable per-recipient feedback in the UI.

  Returns `{:ok, [realized]}` when every recipient resolves cleanly, or
  `{:error, [reason]}` when one or more recipients have a nil value for a
  token actually used in the template.
  """
  @spec realize(template(), EmailContext.t()) :: {:ok, [realized()]} | {:error, [reason()]}
  def realize(
        %{subject: subject_t, html_body: html_t, text_body: text_t} = template,
        %EmailContext{} = context
      )
      when is_binary(subject_t) and is_binary(html_t) and is_binary(text_t) do
    context.recipients
    |> Enum.map(&realize_one(template, &1, context))
    |> partition()
  end

  defp realize_one(template, recipient, context) do
    values = values_for(recipient, context)
    html_values = escape_values_for_html(values)

    with {:ok, subject} <- Substitution.apply(template.subject, values),
         {:ok, html_body} <- Substitution.apply(template.html_body, html_values),
         {:ok, text_body} <- Substitution.apply(template.text_body, values) do
      {:ok,
       %{
         user_id: recipient.student_id,
         email: recipient.email,
         subject: subject,
         html_body: html_body,
         text_body: text_body
       }}
    else
      {:error, nil_value_errors} ->
        {:error,
         Enum.map(nil_value_errors, fn {:nil_value, token} ->
           {:realize_failed, recipient.email, token}
         end)}
    end
  end

  # HTML-escape values flowing into html_body to prevent script injection via recipient names.
  defp escape_values_for_html(values) do
    Map.new(values, fn
      {k, v} when is_binary(v) -> {k, html_escape(v)}
      {k, v} -> {k, v}
    end)
  end

  defp html_escape(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp partition(results) do
    {oks, errors} =
      Enum.reduce(results, {[], []}, fn
        {:ok, realized}, {oks, errs} -> {[realized | oks], errs}
        {:error, reasons}, {oks, errs} -> {oks, reasons ++ errs}
      end)

    case errors do
      [] -> {:ok, Enum.reverse(oks)}
      errs -> {:error, Enum.reverse(errs)}
    end
  end

  @doc """
  Builds the substitution values map for a recipient + context. Values
  may be `nil` for recipients with missing data; the validator is
  responsible for catching that before substitution runs.
  """
  @spec values_for(EmailContext.recipient(), EmailContext.t()) :: %{
          required(String.t()) => String.t() | nil
        }
  def values_for(recipient, %EmailContext{} = context) do
    %{
      "first_name" => nilify(recipient.given_name),
      "student_name" => student_name(recipient),
      "course_name" => context.course_title,
      "instructor_name" => context.instructor_name
    }
  end

  defp student_name(%{given_name: g, family_name: f})
       when is_binary(g) and is_binary(f) do
    case {String.trim(g), String.trim(f)} do
      {"", ""} -> nil
      {"", trimmed_f} -> trimmed_f
      {trimmed_g, ""} -> trimmed_g
      {trimmed_g, trimmed_f} -> "#{trimmed_g} #{trimmed_f}"
    end
  end

  defp student_name(%{given_name: g}) when is_binary(g) do
    case String.trim(g) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp student_name(_), do: nil

  defp nilify(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      _ -> value
    end
  end

  defp nilify(value), do: value
end
