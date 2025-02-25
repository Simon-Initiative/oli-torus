defmodule Oli.Delivery.GrantedCertificates do
  @moduledoc """
  The Granted Certificates context
  """

  import Ecto.Query, warn: false
  require Logger

  alias Ecto.Changeset
  alias ExAws.Lambda
  alias Oli.Delivery.Sections.Certificates.Workers.{GeneratePdf, Mailer}
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Certificates.CertificateRenderer
  alias Oli.Delivery.Sections.Certificate
  alias Oli.Delivery.Sections.Certificates.Workers.GeneratePdf
  alias Oli.Delivery.Sections.GrantedCertificate
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.{HTTP, Repo}

  @doc """
  Creates a granted certificate.
  """
  def create(attrs) do
    attrs |> GrantedCertificate.changeset() |> Repo.insert()
  end

  @doc """
  Updates a granted certificate.
  """
  def update(%GrantedCertificate{} = granted_certificate, attrs) do
    granted_certificate |> GrantedCertificate.changeset(attrs) |> Repo.update()
  end

  @doc """
  Returns the granted certificate with the given guid.
  """
  def get_granted_certificate_by_guid(guid) do
    Repo.get_by(GrantedCertificate, guid: guid)
  end

  @doc """
  Generates a .pdf for the granted certificate with the given id by invoking a lambda function.
  The granted certificate must exist and not have a url already.
  """
  def generate_pdf(granted_certificate_id) do
    case Repo.get(GrantedCertificate, granted_certificate_id) do
      nil ->
        {:error, :granted_certificate_not_found}

      gc ->
        gc.guid
        |> invoke_lambda(CertificateRenderer.render(gc))
        |> case do
          {:error, error} ->
            {:error, :invoke_lambda_error, error}

          {:ok, result} ->
            if result["statusCode"] == 200 do
              gc
              |> Changeset.change(url: certificate_s3_url(gc.guid))
              |> Repo.update()
            else
              {:error, :error_generating_pdf, result}
            end
        end
    end
  end

  @doc """
  Updates a granted certificate with the given attributes.
  This update does not trigger the generation of a .pdf.
  (we use it, for example, to invalidate a granted certificate by updating its state to :denied)

  If in the future we have some cases where we need to update the granted certificate and generate a .pdf
  we should create another function or extend this one with a third argument to indicate if we should do so
  """
  def update_granted_certificate(granted_certificate_id, attrs) do
    Repo.get(GrantedCertificate, granted_certificate_id)
    |> GrantedCertificate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Set up a certificate with distinction and generate the PDF.
  """

  def update_granted_certificate_with_distinction(%GrantedCertificate{} = granted_certificate) do
    granted_certificate
    |> Oli.Delivery.GrantedCertificates.update(%{with_distinction: true})
    |> case do
      {:ok, gc} ->
        %{granted_certificate_id: gc.id} |> GeneratePdf.new() |> Oban.insert()
        {:ok, gc}

      error ->
        log_error(error, granted_certificate.user_id, granted_certificate.id, :update)
    end
  end

  @doc """
  Creates a new granted certificate and schedules a job to generate the .pdf
  if the certificate has an :earned state.

  An optional argument can be passed to indicate if we should send an email to the student
  that has earned the certificate.
  """

  def create_granted_certificate(attrs, opts \\ [send_email?: true])

  def create_granted_certificate(attrs, opts) do
    attrs = Map.merge(attrs, %{issued_at: DateTime.utc_now()})

    %GrantedCertificate{}
    |> GrantedCertificate.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, %{state: :earned, id: id} = granted_certificate} ->
        # This oban job will create the pdf and update the granted_certificate.url
        # only for certificates with the :earned state (:denied ones do not need a .pdf)
        # after the job finishes, it will schedule another job to send an email to the student (Mailer Worker)
        GeneratePdf.new(%{granted_certificate_id: id, send_email?: opts[:send_email?]})
        |> Oban.insert()

        {:ok, granted_certificate}

      {:ok, granted_certificate} ->
        {:ok, granted_certificate}

      error ->
        error
    end
  end

  @doc """
  Sends an email to the given email address with the given template, to inform the student
  about the status of the granted certificate.
  """
  def send_certificate_email(granted_certificate_id, to, template) do
    # TODO: check on MER-4107 if we need to add more assign fields to the email,
    # and if the granted_certificate is updated to mark the student_email_sent field as true
    Mailer.new(%{granted_certificate_id: granted_certificate_id, to: to, template: template})
    |> Oban.insert()
  end

  @doc """
  Fetches all the students that have a granted certificate in the given section with status :earned or :denied,
  and sends them an email with the corresponding template (if they have not been sent yet).
  """
  def bulk_send_certificate_status_email(section_slug) do
    # TODO: check on MER-4107 if we need to add more assign fields to the email,
    # and if the granted_certificate is updated to mark the student_email_sent field as true

    granted_certificates =
      Repo.all(
        from gc in GrantedCertificate,
          join: cert in assoc(gc, :certificate),
          join: s in assoc(cert, :section),
          join: student in assoc(gc, :user),
          where: s.slug == ^section_slug,
          where: gc.state in [:earned, :denied],
          where: gc.student_email_sent == false,
          select: {gc.id, gc.state, student.email}
      )

    granted_certificates
    |> Enum.map(fn {id, state, email} ->
      Mailer.new(%{
        granted_certificate_id: id,
        to: email,
        template: if(state == :earned, do: :certificate_approval, else: :certificate_denial)
      })
    end)
    |> Oban.insert_all()
  end

  @doc """
  Counts the number of granted certificates in the given section that have not been emailed to the students yet.
  (that have the student_email_sent field set to false).
  This count won't include students that haven't yet acomplished the certificate (there is no GrantedCertificate record).
  """
  def certificate_pending_email_notification_count(section_slug) do
    Repo.one(
      from gc in GrantedCertificate,
        join: cert in assoc(gc, :certificate),
        join: s in assoc(cert, :section),
        where: gc.state in [:earned, :denied],
        where: s.slug == ^section_slug,
        where: gc.student_email_sent == false,
        select: count(gc.id)
    )
  end

  defp certificate_s3_url(guid) do
    s3_pdf_bucket = Application.fetch_env!(:oli, :certificates)[:s3_pdf_bucket]
    "https://#{s3_pdf_bucket}.s3.amazonaws.com/certificates/#{guid}.pdf"
  end

  defp invoke_lambda(guid, html) do
    :oli
    |> Application.fetch_env!(:certificates)
    |> Keyword.fetch!(:generate_pdf_lambda)
    |> Lambda.invoke(%{certificate_id: guid, html: html}, %{})
    |> HTTP.aws().request()
  end

  ##### BEGINS EARNING THE CERTIFICATE WORKFLOW SECTION #####

  @doc """
  Checks if a user has been granted a certificate with distinction for a given section.

  Returns `true` if a certificate with distinction exists for the user in the specified section,
  otherwise returns `false`.

  ## Parameters
    - `user_id`: The ID of the user.
    - `section_id`: The ID of the section.

  ## Returns
    - `true` if the user has a certificate with distinction.
    - `false` if no such certificate exists.
  """
  def with_distinction_exists?(user_id, section_id) do
    from(gc in GrantedCertificate,
      join: c in assoc(gc, :certificate),
      where: gc.with_distinction == true,
      where: gc.user_id == ^user_id,
      where: c.section_id == ^section_id,
      select: gc.id
    )
    |> Oli.Repo.exists?()
  end

  @doc """
  Checks if a user needs an eligibility pre-check for certification in a given section.

  Returns `true` if the section has certification enabled and the user has not yet been granted
  a certificate with distinction. Otherwise, returns `false`.

  ## Parameters
    - `user_id`: The ID of the user.
    - `section_id`: The ID of the section.

  ## Returns
    - `true` if the user needs an eligibility pre-check.
    - `false` if the user already has a certificate with distinction or certification is disabled.
  """
  def pre_check_eligibility_needed?(user_id, section_id) do
    from(s in Oli.Delivery.Sections.Section,
      where: s.id == ^section_id and s.certificate_enabled == true,
      where:
        not exists(
          from(gc in GrantedCertificate,
            join: c in Certificate,
            on: gc.certificate_id == c.id,
            where: gc.with_distinction == true,
            where: gc.user_id == ^user_id,
            where: c.section_id == ^section_id
          )
        )
    )
    |> Oli.Repo.exists?()
  end

  @doc """
  Determines whether a user qualifies for a certificate in a given section based on various thresholds.

  ## Parameters
    - `user_id` (integer): The ID of the user being evaluated.
    - `section_id` (integer): The ID of the section in which the user's qualification is being checked.

  ## Returns
    - `{:ok, :no_change}` if the user does not meet the certification criteria or if no update is needed.
    - `{:ok, granted_cert}` if the user qualifies for a certificate (with or without distinction).
    - Other potential return values depend on the results of internal checks.

  ## Process
  1. Retrieves the certification settings and any existing granted certificate.
  2. Checks if the granted certificate is in a valid state to continue processing.
  3. Counts the user's notes and posts in the section.
  4. Validates whether the user meets the note and post thresholds.
  5. Evaluates the user's graded page scores against the required completion and distinction percentages.
  6. Based on the results:
     - If the user meets the basic completion percentage but not distinction, a certificate may be granted.
     - If the user meets both completion and distinction percentages, a certificate with distinction may be granted.
     - If the user does not meet the completion threshold, no changes are made.
  """

  def has_qualified(user_id, section_id) do
    with {cert, granted_cert} <- get_cert_and_maybe_get_granted(user_id, section_id),
         :continue <- check_granted_cert_state(granted_cert),
         {notes_count, posts_count} <- count_notes_and_posts(user_id, section_id),
         :continue <- check_note_and_post_thlds(cert, notes_count, posts_count, granted_cert),
         result <- check_graded_page_thlds(user_id, section_id, cert, granted_cert) do
      case result do
        {:failed_min_percentage_for_completion, :failed_min_percentage_for_distinction} ->
          {:ok, :no_change}

        {:passed_min_percentage_for_completion, :failed_min_percentage_for_distinction} ->
          create_granted_cert_maybe_spawn_builder(user_id, cert, false)

        {:certificate_earned, :failed_min_percentage_for_distinction} ->
          {:ok, :no_change}

        {:certificate_earned, :passed_min_percentage_for_distinction} ->
          update_granted_certificate_with_distinction(granted_cert)

        {:passed_min_percentage_for_completion, :passed_min_percentage_for_distinction} ->
          create_granted_cert_maybe_spawn_builder(user_id, cert, true)
      end

      result
    else
      _ -> {:ok, :no_change}
    end
  end

  _docp = """
  Fetches the certificate for a given section and the granted certificate for a user, if it exists.

  This function retrieves the certificate associated with the specified section and checks
  if the user has already been granted a certificate. If no granted certificate exists,
  it returns `nil` for that part of the tuple.

  ## Parameters
    - `user_id`: The ID of the user.
    - `section_id`: The ID of the section.

  ## Returns
    - A tuple `{cert, granted_cert}` where:
      - `cert` is the certificate for the section.
      - `granted_cert` is the user's granted certificate or `nil` if none exists.
  """

  @spec get_cert_and_maybe_get_granted(binary(), binary()) ::
          {%Certificate{}, %GrantedCertificate{} | nil}
  defp get_cert_and_maybe_get_granted(user_id, section_id) do
    from(c in Certificate,
      left_join: gc in assoc(c, :granted_certificate),
      on: gc.user_id == ^user_id,
      where: c.section_id == ^section_id,
      select: {c, gc}
    )
    |> Oli.Repo.one()
  end

  defp check_granted_cert_state(%GrantedCertificate{state: state, with_distinction: true})
       when state in [:pending, :earned],
       do: :halt

  # def check_granted_cert_state(%GrantedCertificate{state: :denied}), do: :halt

  defp check_granted_cert_state(_granted_certificate), do: :continue

  _docp = """
  Counts the number of notes and posts created by a user in a given section.

  A note is defined as a post with an `annotated_resource_id`, while a post without
  an `annotated_resource_id` is considered a standard post. This function filters only
  public posts.

  ## Parameters
    - `user_id`: The ID of the user.
    - `section_id`: The ID of the section.

  ## Returns
    - A tuple `{notes_count, posts_count}` where:
      - `notes_count` is the number of notes created by the user.
      - `posts_count` is the number of regular posts created by the user.
  """

  @spec count_notes_and_posts(binary(), binary()) :: {integer(), integer()}
  defp count_notes_and_posts(user_id, section_id) do
    from(p in Oli.Resources.Collaboration.Post,
      where: p.visibility == :public,
      where: p.user_id == ^user_id,
      where: p.section_id == ^section_id,
      select: {
        fragment("COUNT(*) FILTER (WHERE ? IS NOT NULL)", p.annotated_resource_id),
        fragment("COUNT(*) FILTER (WHERE ? IS NULL)", p.annotated_resource_id)
      }
    )
    |> Oli.Repo.one()
  end

  defp check_note_and_post_thlds(_cert, _notes_count, _posts_count, %GrantedCertificate{}),
    do: :continue

  defp check_note_and_post_thlds(certificate, notes_count, posts_count, _nil) do
    required_discussion_posts_threshold = certificate.required_discussion_posts
    required_class_notes_threshold = certificate.required_class_notes

    with true <- notes_count >= required_class_notes_threshold,
         true <- posts_count >= required_discussion_posts_threshold do
      :continue
    else
      _ -> :halt
    end
  end

  _doc = """
  Evaluates whether a user meets the grading thresholds required for certificate eligibility.

  This function checks the user's scores on required assignments within a section to determine
  if they qualify for a certificate. It considers both the minimum percentage required for
  completion and the higher threshold for distinction, depending on whether the user has already
  been granted a certificate.

  ## Parameters
    - `user_id`: The ID of the user.
    - `section_id`: The ID of the section.
    - `certificate`: The certificate associated with the section.
    - `granted_certificate`: The user's granted certificate or `nil` if none exists.

  ## Returns
    - If the user already has a certificate (without distinction):
      - A tuple `{:certificate_earned, distinction_status}`, where `distinction_status` indicates
        whether the user met the distinction threshold.
    - If the user has no granted certificate:
      - A tuple `{completion_status, distinction_status}`, where:
        - `completion_status` indicates whether the user met the minimum percentage for completion.
        - `distinction_status` indicates whether the user met the minimum percentage for distinction.
  """

  defp check_graded_page_thlds(
         user_id,
         section_id,
         certificate,
         %GrantedCertificate{with_distinction: false}
       ) do
    min_percentage_for_distinction = certificate.min_percentage_for_distinction
    required_assignment_ids = get_required_assignment_ids(section_id, certificate)
    total_required_assignments = Enum.count(required_assignment_ids)

    current_percentage =
      from(ra in ResourceAccess,
        where: ra.section_id == ^section_id,
        where: ra.user_id == ^user_id,
        where: ra.resource_id in ^required_assignment_ids,
        select:
          fragment(
            "COALESCE(SUM(? / ? * 100) / ?, 0.0)",
            ra.score,
            ra.out_of,
            ^total_required_assignments
          )
      )
      |> Oli.Repo.one()

    distinction_result =
      if current_percentage >= min_percentage_for_distinction,
        do: :passed_min_percentage_for_distinction,
        else: :failed_min_percentage_for_distinction

    {:certificate_earned, distinction_result}
  end

  defp check_graded_page_thlds(user_id, section_id, certificate, nil) do
    min_percentage_for_completion = certificate.min_percentage_for_completion
    min_percentage_for_distinction = certificate.min_percentage_for_distinction
    required_assignment_ids = get_required_assignment_ids(section_id, certificate)

    total_required_assignments = Enum.count(required_assignment_ids)

    current_percentage =
      from(ra in ResourceAccess,
        where: ra.section_id == ^section_id,
        where: ra.user_id == ^user_id,
        where: ra.resource_id in ^required_assignment_ids,
        select:
          fragment(
            "COALESCE(SUM(? / ? * 100) / ?, 0.0)",
            ra.score,
            ra.out_of,
            ^total_required_assignments
          )
      )
      |> Oli.Repo.one()

    completion_result =
      if current_percentage >= min_percentage_for_completion,
        do: :passed_min_percentage_for_completion,
        else: :failed_min_percentage_for_completion

    distinction_result =
      if current_percentage >= min_percentage_for_distinction,
        do: :passed_min_percentage_for_distinction,
        else: :failed_min_percentage_for_distinction

    {completion_result, distinction_result}
  end

  defp get_required_assignment_ids(section_id, certificate) do
    %{
      assessments_apply_to: assessments_apply_to,
      custom_assessments: custom_assessments
    } = certificate

    case assessments_apply_to do
      :all ->
        section_id
        |> SectionResourceDepot.graded_pages(hidden: false)
        |> Enum.map(& &1.resource_id)

      :custom ->
        custom_assessments
    end
  end

  defp create_granted_cert_maybe_spawn_builder(user_id, certificate, with_distinction) do
    attrs = %{
      user_id: user_id,
      certificate_id: certificate.id,
      state: if(certificate.requires_instructor_approval, do: :pending, else: :earned),
      with_distinction: with_distinction,
      guid: Ecto.UUID.generate()
    }

    if certificate.requires_instructor_approval do
      {:ok, :send_email_to_instructor}
    else
      case create_granted_certificate(attrs) do
        {:ok, %GrantedCertificate{}} = gc -> gc
        error -> log_error(error, user_id, certificate.section_id, :insert)
      end
    end
  end

  defp log_error(error, user_id, reference_id, operation) do
    message =
      case operation do
        :insert ->
          "Failed to grant certificate (user_id: #{user_id}, section_id: #{reference_id})"

        :update ->
          "Failed to grant with distinction certificate (user_id: #{user_id}, granted_certificate_id: #{reference_id})"
      end

    Logger.error("#{message}: #{inspect(error)}")
  end

  ##### ENDS EARNING THE CERTIFICATE WORKFLOW SECTION #####
end
