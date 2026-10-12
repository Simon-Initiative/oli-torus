defmodule Oli.Playwright.RecaptchaTest do
  use ExUnit.Case, async: true

  alias Oli.Playwright.Recaptcha

  test "accepts any response without configuration or Google verification" do
    for response <- [nil, "", "arbitrary", 42, [], %{}, ["response"]] do
      assert Recaptcha.verify(response) == {:success, true}
    end
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
