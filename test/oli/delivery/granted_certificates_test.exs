defmodule Oli.Delivery.GrantedCertificatesTest do
  use Oli.DataCase, async: true

  import Mox
  import Oli.Factory

  alias Oli.Delivery.GrantedCertificates
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
end
