defmodule Oli.Delivery.Sections.Certificates.Workers.GeneratePdfTest do
  use Oli.DataCase, async: true
  use Oban.Testing, repo: Oli.Repo
  use OliWeb, :verified_routes

  import Oli.Factory
  import Mox
  import Swoosh.TestAssertions

  alias Oli.Delivery.GrantedCertificates
  alias Oli.Delivery.Sections.Certificates.Workers.GeneratePdf
  alias Oli.Delivery.Sections.Certificates.Workers.Mailer

  describe "Generate Pdf worker" do
    test "generates a pdf for that granted certificate when the job is performed" do
      section = insert(:section, certificate_enabled: true)
      certificate = insert(:certificate, section: section)
      user = insert(:user)

      attrs = %{
        state: :earned,
        user_id: user.id,
        certificate_id: certificate.id,
        with_distinction: false,
        guid: UUID.uuid4()
      }

      {:ok, gc} = GrantedCertificates.create_granted_certificate(attrs)

      assert gc.url == nil

      assert_enqueued(
        worker: GeneratePdf,
        args: %{"granted_certificate_id" => gc.id, "send_email?" => true}
      )

      expect(Oli.Test.MockAws, :request, 1, fn operation ->
        assert operation.data.certificate_id == gc.guid
        {:ok, %{"statusCode" => 200, "body" => %{"s3Path" => "foo/bar"}}}
      end)

      assert {:ok, updated_gc} =
               perform_job(GeneratePdf, %{
                 "granted_certificate_id" => gc.id,
                 "send_email?" => false
               })

      assert updated_gc.url =~ "/certificates/#{gc.guid}.pdf"
    end

    test "enqueues a Mailer job after creating the pdf if `send_email?` flag is set to true" do
      section = insert(:section, certificate_enabled: true)
      certificate = insert(:certificate, section: section)
      user = insert(:user)

      attrs = %{
        state: :earned,
        user_id: user.id,
        certificate_id: certificate.id,
        with_distinction: false,
        guid: UUID.uuid4()
      }

      {:ok, gc} = GrantedCertificates.create_granted_certificate(attrs)

      GeneratePdf.new(%{granted_certificate_id: gc.id, send_email?: true})
      |> Oban.insert()

      expect(Oli.Test.MockAws, :request, 1, fn operation ->
        assert operation.data.certificate_id == gc.guid
        {:ok, %{"statusCode" => 200, "body" => %{"s3Path" => "foo/bar"}}}
      end)

      perform_job(GeneratePdf, %{"granted_certificate_id" => gc.id, "send_email?" => true})

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_guid" => gc.guid,
          "to" => user.email,
          "template" => "student_approval",
          "template_assigns" => %{
            "certificate_link" =>
              Phoenix.VerifiedRoutes.url(
                OliWeb.Endpoint,
                ~p"/sections/#{section.slug}/certificate/#{gc.guid}"
              ),
            "course_name" => section.title,
            "platform_name" => Oli.Branding.brand_name(section),
            "student_name" => OliWeb.Common.Utils.name(user)
          }
        }
      )
    end

    test "the enqueued Mailer job sends the student email with the certificate label (no distinction)" do
      section = insert(:section, certificate_enabled: true)
      certificate = insert(:certificate, section: section)
      user = insert(:user)

      attrs = %{
        state: :earned,
        user_id: user.id,
        certificate_id: certificate.id,
        with_distinction: false,
        guid: UUID.uuid4()
      }

      {:ok, gc} = GrantedCertificates.create_granted_certificate(attrs)

      expect(Oli.Test.MockAws, :request, 1, fn operation ->
        assert operation.data.certificate_id == gc.guid
        {:ok, %{"statusCode" => 200, "body" => %{"s3Path" => "foo/bar"}}}
      end)

      perform_job(GeneratePdf, %{"granted_certificate_id" => gc.id, "send_email?" => true})

      # Performing the Mailer job built by GeneratePdf must not crash on a missing
      # `certificate_label` assign, and must render the label in the email body.
      [mailer_job] = all_enqueued(worker: Mailer)
      assert :ok = perform_job(Mailer, mailer_job.args)

      assert_email_sent(fn email ->
        assert Enum.any?(email.to, fn {_name, addr} -> addr == user.email end)
        assert email.subject == "Congratulations You've Earned a Certificate of Completion"
        assert email.html_body =~ "Certificate of Completion"
      end)
    end

    test "the enqueued Mailer job sends the student email with the certificate label (with distinction)" do
      section = insert(:section, certificate_enabled: true)
      certificate = insert(:certificate, section: section)
      user = insert(:user)

      attrs = %{
        state: :earned,
        user_id: user.id,
        certificate_id: certificate.id,
        with_distinction: true,
        guid: UUID.uuid4()
      }

      {:ok, gc} = GrantedCertificates.create_granted_certificate(attrs)

      expect(Oli.Test.MockAws, :request, 1, fn operation ->
        assert operation.data.certificate_id == gc.guid
        {:ok, %{"statusCode" => 200, "body" => %{"s3Path" => "foo/bar"}}}
      end)

      perform_job(GeneratePdf, %{"granted_certificate_id" => gc.id, "send_email?" => true})

      [mailer_job] = all_enqueued(worker: Mailer)
      assert :ok = perform_job(Mailer, mailer_job.args)

      assert_email_sent(fn email ->
        assert Enum.any?(email.to, fn {_name, addr} -> addr == user.email end)
        assert email.subject == "Congratulations You've Earned a Certificate with Distinction"
        assert email.html_body =~ "Certificate with Distinction"
      end)
    end

    test "does not enqueue a Mailer job after creating the pdf if `send_email?` flag is set to false" do
      section = insert(:section, certificate_enabled: true)
      certificate = insert(:certificate, section: section)
      user = insert(:user)

      attrs = %{
        state: :denied,
        user_id: user.id,
        certificate_id: certificate.id,
        with_distinction: false,
        guid: UUID.uuid4()
      }

      {:ok, gc} = GrantedCertificates.create_granted_certificate(attrs)

      GeneratePdf.new(%{granted_certificate_id: gc.id, send_email?: false})
      |> Oban.insert()

      expect(Oli.Test.MockAws, :request, 1, fn operation ->
        assert operation.data.certificate_id == gc.guid
        {:ok, %{"statusCode" => 200, "body" => %{"s3Path" => "foo/bar"}}}
      end)

      perform_job(GeneratePdf, %{"granted_certificate_id" => gc.id, "send_email?" => false})

      refute_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc.id,
          # this should be updated with the real user email
          "to" => "dummy@email.com",
          "template" => :certificate_approval
        }
      )
    end
  end
end
