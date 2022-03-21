defmodule OliWeb.ActivityBankViewTest do
  use OliWeb.ConnCase, async: true

  describe "activity_bank_view" do
    import OliWeb.ActivityBankView

    test "Escape a JS JSON string with a potential XSS attack" do
      result = json_escape(%{evilParam: "</script>"})
      assert result == {:safe, "{%22evilParam%22:%22%3C/script%3E%22}"}
    end

    test "Does not cause an XSS vulnerability", %{conn: conn} do
      testConn = conn |> put_private(:phoenix_endpoint, OliWeb.Endpoint)

      result =
        Phoenix.View.render_to_string(OliWeb.ActivityBankView, "index.html",
          conn: testConn,
          scripts: [],
          context: %{evilParam: "</script>"}
        )

      assert result =~ "const encodedParams = \"{%22evilParam%22:%22%3C/script%3E%22}\";"
    end
  end
end
