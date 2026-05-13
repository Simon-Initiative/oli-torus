defmodule Oli.InstructorDashboard.Email.Validator do
  @moduledoc """
  Server-authoritative pre-send validation: non-empty recipients, well-formed
  emails, whitelisted placeholders, and per-recipient token resolvability.
  Returns `:ok` or `{:error, [reason()]}`.
  """

  alias Oli.InstructorDashboard.Email.{EmailContext, Realization, Substitution}

  @type reason ::
          :no_recipients
          | {:invalid_email, String.t() | nil}
          | {:invalid_instructor_email, String.t() | nil}
          | {:unsupported_placeholder, String.t()}
          | {:unresolvable_placeholder, String.t(), [String.t()]}

  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @recipient_derived_tokens ~w({first_name} {student_name})

  @doc "Validates the rendered template against the recipient roster."
  @spec validate(Realization.template(), EmailContext.t()) ::
          :ok | {:error, [reason()]}
  def validate(template, %EmailContext{} = context) do
    reasons =
      []
      |> check_recipients(context)
      |> check_emails(context)
      |> check_instructor_email(context)
      |> check_unsupported_tokens(template)
      |> check_token_resolvability(template, context)

    case reasons do
      [] -> :ok
      errs -> {:error, Enum.reverse(errs)}
    end
  end

  defp check_recipients(reasons, %EmailContext{recipients: []}),
    do: [:no_recipients | reasons]

  defp check_recipients(reasons, %EmailContext{recipients: r}) when is_list(r), do: reasons

  defp check_emails(reasons, %EmailContext{recipients: recipients}) do
    Enum.reduce(recipients, reasons, fn recipient, acc ->
      if is_binary(recipient.email) and Regex.match?(@email_regex, recipient.email) do
        acc
      else
        [{:invalid_email, recipient.email} | acc]
      end
    end)
  end

  # instructor_email is optional (nil/"" means no reply_to set). If set, it
  # MUST be a well-formed address — otherwise it lands in the outbound
  # Reply-To header where malformed values can break clients or misdirect
  # replies.
  defp check_instructor_email(reasons, %EmailContext{instructor_email: nil}), do: reasons
  defp check_instructor_email(reasons, %EmailContext{instructor_email: ""}), do: reasons

  defp check_instructor_email(reasons, %EmailContext{instructor_email: addr}) do
    if is_binary(addr) and Regex.match?(@email_regex, addr) do
      reasons
    else
      [{:invalid_instructor_email, addr} | reasons]
    end
  end

  defp check_unsupported_tokens(reasons, %{subject: subj, html_body: html, text_body: text}) do
    [subj, html, text]
    |> Enum.flat_map(&Substitution.unsupported_tokens/1)
    |> Enum.uniq()
    |> Enum.reduce(reasons, fn token, acc ->
      [{:unsupported_placeholder, token} | acc]
    end)
  end

  # Only recipient-derived tokens can be unresolvable; context-derived tokens
  # ({course_name}, {instructor_name}) are guaranteed non-nil by ContextBuilder.
  defp check_token_resolvability(reasons, template, %EmailContext{} = context) do
    used =
      template.subject
      |> Substitution.used_tokens()
      |> Kernel.++(Substitution.used_tokens(template.text_body))
      |> Kernel.++(Substitution.used_tokens(template.html_body))
      |> Enum.uniq()
      |> Enum.filter(&(&1 in @recipient_derived_tokens))

    case used do
      [] ->
        reasons

      _ ->
        # Precompute each recipient's values map once (avoids O(tokens × recipients)
        # values_for builds).
        recipient_values =
          Enum.map(context.recipients, fn recipient ->
            {recipient.email, Realization.values_for(recipient, context)}
          end)

        Enum.reduce(used, reasons, fn token, acc ->
          key = token |> String.trim_leading("{") |> String.trim_trailing("}")

          unresolved =
            recipient_values
            |> Enum.filter(fn {_email, values} -> is_nil(Map.get(values, key)) end)
            |> Enum.map(fn {email, _values} -> email end)

          case unresolved do
            [] -> acc
            emails -> [{:unresolvable_placeholder, token, emails} | acc]
          end
        end)
    end
  end
end
