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
      certificate_url = "https://some.example.url"

      expect(Oli.Test.MockAws, :request, 1, fn operation ->
        assert operation.data.html == html
        {:ok, %{status_code: 200, body: %{certificate_url: certificate_url}}}
      end)

      assert {:ok, certificate} = Certificates.create(ctx.user.id, ctx.section.id, html)
      assert certificate.user_id == ctx.user.id
      assert certificate.section_id == ctx.section.id
      assert certificate.certificate_url == certificate_url
    end

    test "fails when creating a duplicate certificate", ctx do
      expect(Oli.Test.MockAws, :request, 4, fn operation ->
        {:ok,
         %{status_code: 200, body: %{certificate_url: "https://#{operation.data.html}.example"}}}
      end)

      section2 = insert(:section)
      section3 = insert(:section)

      assert {:ok, _certificate} = Certificates.create(ctx.user.id, ctx.section.id, "foo")
      assert {:ok, _certificate} = Certificates.create(ctx.user.id, section2.id, "bar")

      # Duplicate section
      assert {:error, dupuser} = Certificates.create(ctx.user.id, section2.id, "qux")
      assert {"has already been taken", _} = dupuser.errors[:user_id]

      # Duplicate certificate
      assert {:error, dupcert} = Certificates.create(ctx.user.id, section3.id, "foo")
      assert {"has already been taken", _} = dupcert.errors[:certificate_url]
    end

    test "fails if aws operation fails", ctx do
      expect(Oli.Test.MockAws, :request, 1, fn _ ->
        {:error, %{status_code: 500, body: %{error: "Internal server error"}}}
      end)

      assert {:error, _error} = Certificates.create(ctx.user.id, ctx.section.id, "foo")
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
