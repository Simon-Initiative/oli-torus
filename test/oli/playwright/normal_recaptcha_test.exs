defmodule Oli.Playwright.NormalRecaptchaTest do
  use ExUnit.Case, async: true
  import Mox
  setup :verify_on_exit!

  test "normal verifier still posts to Google and honors its response" do
    for accepted <- [true, false] do
      expect(Oli.Test.MockHTTP, :post, fn url, body, _headers, _options ->
        assert url == "https://www.google.com/recaptcha/api/siteverify"
        assert URI.decode_query(body)["response"] == "google-response"
        {:ok, %HTTPoison.Response{body: Jason.encode!(%{"success" => accepted})}}
      end)

      assert Oli.Utils.Recaptcha.verify("google-response") == {:success, accepted}
    end
  end

  test "normal verifier rejects absent responses and Google errors" do
    assert Oli.Utils.Recaptcha.verify(nil) == {:success, false}
    assert Oli.Utils.Recaptcha.verify("") == {:success, false}
    expect(Oli.Test.MockHTTP, :post, fn _, _, _, _ -> {:error, :unavailable} end)
    assert Oli.Utils.Recaptcha.verify("google-response") == {:success, false}
  end
end
