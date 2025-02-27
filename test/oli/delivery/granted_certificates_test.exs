defmodule Oli.Delivery.GrantedCertificatesTest do
  use Oli.DataCase, async: true
  use Oban.Testing, repo: Oli.Repo

  import Mox
  import Oli.Factory

  alias Oli.Delivery.GrantedCertificates
  alias Oli.Delivery.Sections.Certificates.Workers.GeneratePdf
  alias Oli.Delivery.Sections.GrantedCertificate

  describe "generate_pdf/1" do
    test "generates a pdf certificate in a lambda function and stores the url" do
      gc = insert(:granted_certificate)

      assert gc.url == nil

      expect(Oli.Test.MockAws, :request, 1, fn operation ->
        assert operation.data.certificate_id == gc.guid
        {:ok, %{"statusCode" => 200, "body" => %{"s3Path" => "foo/bar"}}}
      end)

      assert {:ok, _multi} = GrantedCertificates.generate_pdf(gc.id)
      assert Repo.get(GrantedCertificate, gc.id).url =~ "/certificates/#{gc.guid}.pdf"
    end

    test "fails if aws operation fails" do
      gc = insert(:granted_certificate)

      expect(Oli.Test.MockAws, :request, 1, fn _operation ->
        {:ok, %{"statusCode" => 500, "body" => %{"error" => "Internal server error"}}}
      end)

      assert {:error, :error_generating_pdf, _} = GrantedCertificates.generate_pdf(gc.id)
    end
  end

  describe "create_granted_certificate/1" do
    setup do
      section = insert(:section, certificate_enabled: true)
      certificate = insert(:certificate, section: section)
      [user_1, user_2] = insert_pair(:user)

      %{section: section, certificate: certificate, user_1: user_1, user_2: user_2}
    end

    test "creates a new granted certificate (no oban job) when state is not :earned", %{
      certificate: certificate,
      user_1: user_1,
      user_2: user_2
    } do
      attrs = %{
        state: :denied,
        user_id: user_1.id,
        certificate_id: certificate.id,
        with_distinction: false,
        guid: UUID.uuid4()
      }

      assert {:ok, gc} = GrantedCertificates.create_granted_certificate(attrs)
      assert gc.state == :denied
      refute gc.with_distinction

      refute_enqueued(
        worker: GeneratePdf,
        args: %{"granted_certificate_id" => gc.id}
      )

      attrs_2 = %{
        state: :pending,
        user_id: user_2.id,
        certificate_id: certificate.id,
        with_distinction: true,
        guid: UUID.uuid4()
      }

      assert {:ok, gc_2} = GrantedCertificates.create_granted_certificate(attrs_2)
      assert gc_2.state == :pending
      assert gc_2.with_distinction

      refute_enqueued(
        worker: GeneratePdf,
        args: %{"granted_certificate_id" => gc.id}
      )
    end

    test "creates a new granted certificate and an oban job is enqueued when state is :earned", %{
      certificate: certificate,
      user_1: user_1
    } do
      attrs = %{
        state: :earned,
        user_id: user_1.id,
        certificate_id: certificate.id,
        with_distinction: false,
        guid: UUID.uuid4()
      }

      assert {:ok, gc} = GrantedCertificates.create_granted_certificate(attrs)
      assert gc.state == :earned
      refute gc.with_distinction

      # this oban job will enqueue another job to send an email to the student
      # after creating the pdf
      assert_enqueued(
        worker: GeneratePdf,
        args: %{"granted_certificate_id" => gc.id, "send_email?" => true}
      )
    end

    test "returns an error-changeset when the attrs are invalid", %{certificate: certificate} do
      attrs = %{
        state: :denied,
        user_id: nil,
        certificate_id: certificate.id,
        with_distinction: false
      }

      assert {:error, changeset} = GrantedCertificates.create_granted_certificate(attrs)
      assert changeset.errors[:user_id] == {"can't be blank", [validation: :required]}
    end
  end

  describe "update_granted_certificate/2" do
    test "updates a granted certificate with the given attributes" do
      gc = insert(:granted_certificate, state: :denied)

      assert {:ok, gc} = GrantedCertificates.update_granted_certificate(gc.id, %{state: :earned})
      assert gc.state == :earned
    end

    test "returns an error-changeset when the attrs are invalid" do
      gc = insert(:granted_certificate, state: :denied)

      assert {:error, changeset} =
               GrantedCertificates.update_granted_certificate(gc.id, %{state: nil})

      assert changeset.errors[:state] == {"can't be blank", [validation: :required]}
    end
  end

  describe "send_certificate_email/3" do
    test "schedules an oban job to send the corresponding email" do
      granted_certificate = insert(:granted_certificate)

      GrantedCertificates.send_certificate_email(
        granted_certificate.id,
        "some@email.com",
        :certificate_approval
      )

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => granted_certificate.id,
          "to" => "some@email.com",
          "template" => "certificate_approval"
        }
      )
    end
  end

  describe "bulk_send_certificate_status_email/1" do
    test "schedules oban jobs to send the corresponding email to all students that haven't yet received the notification" do
      section = insert(:section)
      certificate = insert(:certificate, section: section)

      [gc_1, gc_2] =
        insert_pair(:granted_certificate,
          state: :earned,
          certificate: certificate,
          student_email_sent: false
        )

      [gc_3, gc_4] =
        insert_pair(:granted_certificate,
          state: :denied,
          certificate: certificate,
          student_email_sent: false
        )

      [gc_5, gc_6] =
        insert_pair(:granted_certificate,
          state: :earned,
          certificate: certificate,
          student_email_sent: true
        )

      GrantedCertificates.bulk_send_certificate_status_email(section.slug)

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_1.id,
          "to" => gc_1.user.email,
          "template" => "certificate_approval"
        }
      )

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_2.id,
          "to" => gc_2.user.email,
          "template" => "certificate_approval"
        }
      )

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_3.id,
          "to" => gc_3.user.email,
          "template" => "certificate_denial"
        }
      )

      assert_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_4.id,
          "to" => gc_4.user.email,
          "template" => "certificate_denial"
        }
      )

      refute_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_5.id,
          "to" => gc_5.user.email,
          "template" => "certificate_approval"
        }
      )

      refute_enqueued(
        worker: Oli.Delivery.Sections.Certificates.Workers.Mailer,
        args: %{
          "granted_certificate_id" => gc_6.id,
          "to" => gc_6.user.email,
          "template" => "certificate_approval"
        }
      )
    end
  end

  describe "certificate_pending_email_notification_count/1" do
    test "returns the count of granted certificates that have not been emailed to the students yet" do
      section = insert(:section)
      certificate = insert(:certificate, section: section)

      [_gc_1, _gc_2] =
        insert_pair(:granted_certificate,
          state: :earned,
          certificate: certificate,
          student_email_sent: false
        )

      [_gc_3, _gc_4] =
        insert_pair(:granted_certificate,
          state: :denied,
          certificate: certificate,
          student_email_sent: false
        )

      [_gc_5, _gc_6] =
        insert_pair(:granted_certificate,
          state: :earned,
          certificate: certificate,
          student_email_sent: true
        )

      assert GrantedCertificates.certificate_pending_email_notification_count(section.slug) == 4
    end
  end
end
