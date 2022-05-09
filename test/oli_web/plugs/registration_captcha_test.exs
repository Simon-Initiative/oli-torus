defmodule Oli.Plugs.RegistrationCaptchaTest do
  use OliWeb.ConnCase
  alias OliWeb.Router.Helpers, as: Routes

  describe "registration_captcha plug" do
    setup [:configure_age_verification]

    test "Renders correct form after user-registration captcha fails", %{conn: conn} do
      # Detects MER-1102
      register_path = Routes.pow_registration_path(conn, :create)

      expect_recaptcha_http_failure_post()

      conn =
        post(conn, register_path,
          user: %{
            email: "first.last@example.com",
            given_name: "First",
            family_name: "Last",
            password: "samplepass",
            password_confirmation: "samplepass"
          },
          "g-recaptcha-response": "iNVALID cAPTCHA"
        )

      assert html_response(conn, 200) =~ "Create a Learner/Educator Account"

      assert html_response(conn, 200) =~ "I am 13 or older"

      assert html_response(conn, 200) =~
               "Captcha failed, please try again"
    end
  end

  test "Renders correct form after author-registration captcha fails", %{conn: conn} do
    # Detects MER-1100
    register_path = Routes.authoring_pow_registration_path(conn, :create)

    expect_recaptcha_http_failure_post()

    conn =
      post(conn, register_path,
        user: %{
          email: "first.last@example.com",
          given_name: "First",
          family_name: "Last",
          password: "samplepass",
          password_confirmation: "samplepass"
        },
        "g-recaptcha-response": "iNVALID cAPTCHA"
      )

    assert html_response(conn, 200) =~ "Create an Authoring Account"

    assert html_response(conn, 200) =~
             "Captcha failed, please try again"
  end

  defp configure_age_verification(_) do
    Config.Reader.read!("test/config/age_verification_config.exs")
    |> Application.put_all_env()

    on_exit(fn ->
      Config.Reader.read!("test/config/config.exs")
      |> Application.put_all_env()
    end)
  end
end
