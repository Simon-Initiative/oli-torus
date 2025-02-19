defmodule Oli.Delivery.Sections.Certificates.Workers.GeneratePdfTest do
  use Oli.DataCase, async: true
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory
  import Mox

  alias Oli.Delivery.GrantedCertificates
  alias Oli.Delivery.Sections.Certificates.Workers.GeneratePdf

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
        args: %{"granted_certificate_id" => gc.id}
      )

      expect(Oli.Test.MockAws, :request, 1, fn operation ->
        assert operation.data.certificate_id == gc.guid
        {:ok, %{"statusCode" => 200, "body" => %{"s3Path" => "foo/bar"}}}
      end)

      assert {:ok, updated_gc} = perform_job(GeneratePdf, %{"granted_certificate_id" => gc.id})

      assert updated_gc.url =~ "/certificates/#{gc.guid}.pdf"
    end
  end
end
