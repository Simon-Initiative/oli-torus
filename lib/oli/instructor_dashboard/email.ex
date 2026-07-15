defmodule Oli.InstructorDashboard.Email do
  @moduledoc """
  Public API for the instructor-dashboard AI email feature. External
  callers use this module only; internals (`Substitution`, `Realization`,
  `Validator`, `SendWorker`, `AIDraftFacade`, …) stay private to the
  folder.
  """

  alias Oli.InstructorDashboard.Email.{
    AIDraftFacade,
    EmailContext,
    Realization,
    SendWorker,
    SlateSanitizer,
    Validator
  }

  alias Oli.Mailer.SendEmailWorker
  alias Oli.Rendering.Content, as: RenderContent
  alias Oli.Rendering.Content.Html, as: HtmlWriter
  alias Oli.Rendering.Context, as: RenderContext

  @type draft :: %{
          required(:subject) => String.t(),
          required(:body_slate) => [map()]
        }

  @type send_ok ::
          {:ok, %{enqueued: non_neg_integer(), draft_id: String.t()}}

  @type send_error ::
          {:error, [Validator.reason()]}

  @validation_blocked [:oli, :instructor_dashboard, :email, :send, :validation_blocked]
  @realize_blocked [:oli, :instructor_dashboard, :email, :send, :realize_blocked]

  @doc "Generates an AI-drafted subject + body template for the given context."
  defdelegate generate_draft(context, opts \\ []), to: AIDraftFacade, as: :generate

  @doc "Renders the draft and validates it for sending."
  @spec validate(draft(), EmailContext.t()) :: :ok | {:error, [Validator.reason()]}
  def validate(%{subject: subject, body_slate: body_slate}, %EmailContext{} = context)
      when is_binary(subject) and is_list(body_slate) do
    subject
    |> render_template(body_slate, context.section_slug)
    |> Validator.validate(context)
  end

  @doc """
  Validates the draft, realizes per-recipient strings, and enqueues one
  `SendWorker` job per recipient.

  Returns `{:ok, %{enqueued, draft_id}}` on success. Returns `{:error,
  reasons}` when validation rejects the draft OR when realization detects
  unresolvable per-recipient data after a successful validation (race
  condition or validator gap). Emits `:validation_blocked` telemetry on
  validation failure and `:realize_blocked` telemetry on realization
  failure so admins can detect validator drift.

  System-level enqueue failures (`Oban.insert_all` raising) propagate.
  """
  @spec send_emails(draft(), EmailContext.t()) :: send_ok() | send_error()
  def send_emails(%{subject: subject, body_slate: body_slate}, %EmailContext{} = context)
      when is_binary(subject) and is_list(body_slate) do
    template = render_template(subject, body_slate, context.section_slug)

    with :ok <- run_validation(template, context),
         {:ok, per_recipient} <- run_realization(template, context) do
      draft_id = UUID.uuid4()
      jobs = enqueue(per_recipient, context, draft_id)
      enqueued = Enum.count(jobs, &(not &1.conflict?))

      {:ok, %{enqueued: enqueued, draft_id: draft_id}}
    end
  end

  defp render_template(subject, body_slate, section_slug) do
    fragment = render_html_fragment(body_slate, section_slug)
    wrapped = "<html><body>" <> fragment <> "</body></html>"
    text = Premailex.to_text(wrapped)

    %{subject: subject, html_body: wrapped, text_body: text, body_slate: body_slate}
  end

  defp render_html_fragment(body_slate, section_slug) do
    # Authoritative gate: re-sanitize to the email subset regardless of how body_slate was set,
    # and disable the renderer's unsupported-node error writer (it interpolates a raw element
    # type into HTML) so a stray node can never inject markup into the sent email.
    %RenderContext{
      is_annotation_level: false,
      section_slug: section_slug,
      render_opts: %{render_errors: false, render_point_markers: false}
    }
    |> RenderContent.render(SlateSanitizer.sanitize(body_slate), HtmlWriter)
    |> IO.iodata_to_binary()
  end

  defp run_validation(template, context) do
    case Validator.validate(template, context) do
      :ok ->
        :ok

      {:error, reasons} = error ->
        :telemetry.execute(@validation_blocked, %{}, %{
          section_id: context.section_id,
          situation_key: context.situation_key,
          reasons: sanitize_reasons_for_telemetry(reasons)
        })

        error
    end
  end

  defp run_realization(template, context) do
    case Realization.realize(template, context) do
      {:ok, _per_recipient} = ok ->
        ok

      {:error, reasons} = error ->
        :telemetry.execute(@realize_blocked, %{}, %{
          section_id: context.section_id,
          situation_key: context.situation_key,
          reasons: sanitize_reasons_for_telemetry(reasons)
        })

        error
    end
  end

  # Strip PII from reasons before telemetry; caller-facing tuple retains emails.
  defp sanitize_reasons_for_telemetry(reasons) do
    Enum.map(reasons, fn
      {:unresolvable_placeholder, token, emails} when is_list(emails) ->
        {:unresolvable_placeholder, token, length(emails)}

      {:realize_failed, _email, token} ->
        {:realize_failed, token}

      {:invalid_email, _email} ->
        :invalid_email

      {:invalid_instructor_email, _addr} ->
        :invalid_instructor_email

      {:duplicate_recipients, ids} when is_list(ids) ->
        {:duplicate_recipients, length(ids)}

      {:unsafe_link, _url} ->
        :unsafe_link

      other ->
        other
    end)
  end

  defp enqueue(per_recipient, %EmailContext{} = context, draft_id) do
    per_recipient
    |> Enum.map(fn realized ->
      email = build_email(realized, context)

      SendWorker.new(%{
        "email" => SendEmailWorker.serialize_email(email),
        "draft_id" => draft_id,
        "user_id" => realized.user_id,
        "section_id" => context.section_id,
        "situation_key" => to_string(context.situation_key)
      })
    end)
    |> Oban.insert_all()
  end

  defp build_email(realized, %EmailContext{} = context) do
    Oli.Email.base_email()
    |> Swoosh.Email.to(realized.email)
    |> Swoosh.Email.subject(realized.subject)
    |> Swoosh.Email.html_body(realized.html_body)
    |> Swoosh.Email.text_body(realized.text_body)
    |> maybe_reply_to(context)
  end

  defp maybe_reply_to(email, %EmailContext{instructor_email: nil}), do: email

  defp maybe_reply_to(email, %EmailContext{instructor_email: ""}), do: email

  defp maybe_reply_to(email, %EmailContext{instructor_name: name, instructor_email: addr}) do
    Swoosh.Email.reply_to(email, {name, addr})
  end
end
