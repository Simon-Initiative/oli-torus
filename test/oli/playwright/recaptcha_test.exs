defmodule Oli.Playwright.RecaptchaTest do
  use ExUnit.Case, async: false

  alias Oli.Playwright.Recaptcha

  setup do
    original = Application.fetch_env(:oli, :playwright_captcha_token)
    Application.put_env(:oli, :playwright_captcha_token, "runner-secret")

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:oli, :playwright_captcha_token, value)
        :error -> Application.delete_env(:oli, :playwright_captcha_token)
      end
    end)
  end

  test "accepts only the current runtime token without Google verification" do
    assert Recaptcha.verify("runner-secret") == {:success, true}

    for response <- [nil, "", "arbitrary", 42, [], %{}, ["response"]] do
      assert Recaptcha.verify(response) == {:success, false}
    end

    Application.put_env(:oli, :playwright_captcha_token, "rotated-secret")
    assert Recaptcha.verify("runner-secret") == {:success, false}
    assert Recaptcha.verify("rotated-secret") == {:success, true}
  end

  test "fails closed when the server token is absent or empty" do
    for token <- [nil, ""] do
      Application.put_env(:oli, :playwright_captcha_token, token)
      assert Recaptcha.verify(token) == {:success, false}
      assert Recaptcha.verify("runner-secret") == {:success, false}
    end

    Application.delete_env(:oli, :playwright_captcha_token)
    assert Recaptcha.verify(nil) == {:success, false}
  end

  test "request filtering redacts captcha fields including LiveView nested params" do
    assert Phoenix.Logger.filter_values(%{
             "g-recaptcha-response" => "private",
             "user" => %{"g-recaptcha-response" => "private", "password" => "private"}
           }) == %{
             "g-recaptcha-response" => "[FILTERED]",
             "user" => %{"g-recaptcha-response" => "[FILTERED]", "password" => "[FILTERED]"}
           }
  end
end
