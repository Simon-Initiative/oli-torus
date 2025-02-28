defmodule Oli.Delivery.Sections.Certificates.Workers.MailerTest do
  use Oli.DataCase, async: true
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory
  import Swoosh.TestAssertions

  alias Oli.Delivery.Sections.Certificates.Workers.Mailer

  describe "Mailer worker" do
    test "sends an email to the instructor when the job is performed with the template `instructor_notification`" do
      granted_certificate = insert(:granted_certificate)

      {:ok, job} =
        Mailer.new(%{
          granted_certificate_guid: granted_certificate.guid,
          to: "some_instructor@test.com",
          template: "instructor_notification",
          template_assigns: %{
            instructor_name: "Instructor Messi",
            student_name: "John Doe",
            course_name: "Test Course",
            section_slug: "test-section",
            certificate_type: "certificate of completion"
          }
        })
        |> Oban.insert()

      perform_job(Mailer, job.args)

      assert_email_sent(
        to: "some_instructor@test.com",
        subject: "Torus Certificate Approval Request"
      )
    end

    test "sends an email to the student when the job is performed with the template `student_approval`" do
      ## Without distinction

      granted_certificate = insert(:granted_certificate)

      {:ok, job} =
        Mailer.new(%{
          granted_certificate_guid: granted_certificate.guid,
          to: "some_student@test.com",
          template: "student_approval",
          template_assigns: %{
            student_name: "John Doe",
            course_name: "Test Course",
            platform_name: "Torus",
            certificate_link: "some_url"
          }
        })
        |> Oban.insert()

      perform_job(Mailer, job.args)

      assert_email_sent(
        to: "some_student@test.com",
        subject: "Congratulations You've Earned a Certificate of Completion"
      )

      ## With distinction
      granted_certificate = insert(:granted_certificate, with_distinction: true)

      {:ok, job} =
        Mailer.new(%{
          granted_certificate_guid: granted_certificate.guid,
          to: "some_student@test.com",
          template: "student_approval",
          template_assigns: %{
            student_name: "John Doe",
            course_name: "Test Course",
            platform_name: "Torus",
            certificate_link: "some_url"
          }
        })
        |> Oban.insert()

      perform_job(Mailer, job.args)

      assert_email_sent(
        to: "some_student@test.com",
        subject: "Congratulations You've Earned a Certificate with Distinction"
      )
    end

    test "sends an email to the student when the job is performed with the template `student_denial`" do
      granted_certificate = insert(:granted_certificate, state: :denied)

      {:ok, job} =
        Mailer.new(%{
          granted_certificate_guid: granted_certificate.guid,
          to: "some_student@test.com",
          template: "student_denial",
          template_assigns: %{
            student_name: "John Doe",
            course_name: "Test Course",
            platform_name: "Torus",
            instructor_email: "some_inst@email.com"
          }
        })
        |> Oban.insert()

      perform_job(Mailer, job.args)

      assert_email_sent(
        to: "some_student@test.com",
        subject: "Course Completion Status - Certificate Not Awarded"
      )
    end
  end
end
