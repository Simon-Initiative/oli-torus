defmodule Oli.Delivery.Sections.Certificates.Workers.Mailer do
  use Oban.Worker, queue: :certificate_mailer, max_attempts: 3

  alias Oli.Email
  alias Oli.Mailer
  alias Oli.Delivery.GrantedCertificates

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"template" => "instructor_notification"} = args}) do
    send_email(
      :certificate_instructor_pending_approval,
      args["to"],
      args["template_assigns"],
      "Torus Certificate Approval Request"
    )
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"template" => "student_denial"} = args}) do
    granted_certificate =
      GrantedCertificates.get_granted_certificate_by_guid(args["granted_certificate_guid"])

    send_email(
      :certificate_denial,
      args["to"],
      args["template_assigns"],
      "Course Completion Status - Certificate Not Awarded"
    )
    |> case do
      {:ok, _term} ->
        GrantedCertificates.update(granted_certificate, %{student_email_sent: true})
        :ok

      {:error, _term} ->
        :error
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"template" => "student_approval"} = args}) do
    granted_certificate =
      GrantedCertificates.get_granted_certificate_by_guid(args["granted_certificate_guid"])

    subject = get_subject(granted_certificate)

    send_email(:certificate_approval, args["to"], args["template_assigns"], subject)
    |> case do
      {:ok, _term} ->
        GrantedCertificates.update(granted_certificate, %{student_email_sent: true})
        :ok

      {:error, _term} ->
        :error
    end
  end

  defp get_subject(%{with_distinction: true}),
    do: "Congratulations You've Earned a Certificate with Distinction"

  defp get_subject(%{with_distinction: false}),
    do: "Congratulations You've Earned a Certificate of Completion"

  defp send_email(template, to, template_assigns, subject) do
    Email.create_email(
      to,
      subject,
      template,
      Oli.Utils.atomize_keys(template_assigns)
    )
    |> Mailer.deliver()
  end
end
