defmodule OliWeb.CertificateControllerTest do
  use OliWeb.ConnCase, async: true
  import Oli.Factory

  describe "GET /certificates" do
    test "renders index", %{conn: conn} do
      conn = get(conn, Routes.certificate_path(conn, :index))
      assert html_response(conn, 200) =~ "Certificate Verification"
    end
  end

  describe "POST /certificate/verify" do
    test "verifies a valid certificate", %{conn: conn} do
      certificate = insert(:granted_certificate, state: :earned)
      recaptcha_ok()

      params = %{"guid" => %{"value" => certificate.guid}, "g-recaptcha-response" => "valid"}
      conn = post(conn, Routes.certificate_path(conn, :verify), params)

      assert html_response(conn, 200) =~ certificate.guid
    end

    test "rejects invalid certificate", %{conn: conn} do
      recaptcha_ok()

      params = %{"guid" => %{"value" => "invalid"}, "g-recaptcha-response" => "valid"}
      conn = post(conn, Routes.certificate_path(conn, :verify), params)

      assert html_response(conn, 200) =~ "A certificate with that ID does not exist"
    end

    test "rejects pending certificate", %{conn: conn} do
      certificate = insert(:granted_certificate, state: :pending)

      recaptcha_ok()

      params = %{"guid" => %{"value" => certificate.guid}, "g-recaptcha-response" => "valid"}
      conn = post(conn, Routes.certificate_path(conn, :verify), params)

      assert html_response(conn, 200) =~ "A certificate with that ID does not exist"
    end

    test "rejects denied certificate", %{conn: conn} do
      certificate = insert(:granted_certificate, state: :denied)

      recaptcha_ok()

      params = %{"guid" => %{"value" => certificate.guid}, "g-recaptcha-response" => "valid"}
      conn = post(conn, Routes.certificate_path(conn, :verify), params)

      assert html_response(conn, 200) =~ "A certificate with that ID does not exist"
    end

    test "fails recaptcha validation", %{conn: conn} do
      recaptcha_fail()
      params = %{"guid" => %{"value" => "some-guid"}, "g-recaptcha-response" => "invalid"}
      conn = post(conn, Routes.certificate_path(conn, :verify), params)

      assert html_response(conn, 200) =~ "ReCaptcha failed, please try again"
    end
  end

  defp recaptcha_ok, do: Mox.expect(Oli.Test.RecaptchaMock, :verify, fn _ -> {:success, true} end)

  defp recaptcha_fail,
    do: Mox.expect(Oli.Test.RecaptchaMock, :verify, fn _ -> {:success, false} end)
end
