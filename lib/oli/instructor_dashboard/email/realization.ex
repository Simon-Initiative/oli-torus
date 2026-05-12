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

  @doc """
  Realizes the template into concrete per-recipient strings. Raises if any
  used token is unresolvable for any recipient — the validator must run first.
  """
  @spec realize(template(), EmailContext.t()) :: [realized()]
  def realize(
        %{subject: subject_t, html_body: html_t, text_body: text_t},
        %EmailContext{} = context
      )
      when is_binary(subject_t) and is_binary(html_t) and is_binary(text_t) do
    Enum.map(context.recipients, fn recipient ->
      values = values_for(recipient, context)

      %{
        user_id: recipient.student_id,
        email: recipient.email,
        subject: Substitution.apply(subject_t, values),
        html_body: Substitution.apply(html_t, values),
        text_body: Substitution.apply(text_t, values)
      }
    end)
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
      "first_name" => nilify(recipient[:given_name]),
      "student_name" => student_name(recipient),
      "course_name" => context.course_title,
      "instructor_name" => context.instructor_name
    }
  end

  defp student_name(%{given_name: g, family_name: f})
       when is_binary(g) and g != "" and is_binary(f) and f != "" do
    String.trim("#{g} #{f}")
  end

  defp student_name(%{given_name: g}) when is_binary(g) and g != "", do: g
  defp student_name(_), do: nil

  defp nilify(""), do: nil
  defp nilify(value), do: value
end
