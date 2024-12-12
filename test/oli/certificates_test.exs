defmodule Oli.CertificatesTest do
  use Oli.DataCase, async: true

  import Mox
  import Oli.Factory

  alias Oli.Certificates

  setup do
    [
      user: insert(:user),
      section: insert(:section)
    ]
  end

  describe "create/3" do
    test "creates a certificate", ctx do
      html = "<a>Certificate</a>"

      expect(Oli.Test.MockAws, :request, 1, fn operation ->
        assert operation.data.html == html
        {:ok, %{status_code: 200}}
      end)

      assert {:ok, multi} = Certificates.create(ctx.user.id, ctx.section.id, html)
      assert multi.certificate.user_id == ctx.user.id
      assert multi.certificate.section_id == ctx.section.id
      assert multi.complete_certificate.status == "complete"
    end

    test "fails when creating a duplicate certificate", ctx do
      expect(Oli.Test.MockAws, :request, 4, fn _ -> {:ok, %{status_code: 200}} end)

      assert {:ok, _certificate} = Certificates.create(ctx.user.id, ctx.section.id, "foo")

      assert {:error, :certificate, changeset, _multi} =
               Certificates.create(ctx.user.id, ctx.section.id, "bar")

      assert {"has already been taken", _} = changeset.errors[:user_id]
    end

    test "fails if aws operation fails", ctx do
      expect(Oli.Test.MockAws, :request, 1, fn _ ->
        {:error, %{status_code: 500, body: %{error: "Internal server error"}}}
      end)

      assert {:error, :invoke_lambda, _error, _multi} =
               Certificates.create(ctx.user.id, ctx.section.id, "foo")
    end

    test "fails when html is not a string or empty", ctx do
      assert {:error, :invalid_html} = Certificates.create(ctx.user.id, ctx.section.id, [])
      assert {:error, :invalid_html} = Certificates.create(ctx.user.id, ctx.section.id, "")
    end
  end

  describe "get/1" do
    test "retrieves a certificate by its id" do
      c = insert(:certificate)
      certificate = Certificates.get(c.id)
      assert certificate.id == c.id
    end

    test "retrieves nil if certificate does not exist" do
      refute Certificates.get("00000000-0000-0000-0000-000000000000")
    end
  end
end
