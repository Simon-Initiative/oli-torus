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

      assert_enqueued(
        worker: GeneratePdf,
        args: %{"granted_certificate_id" => gc.id}
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
end
