defmodule OliWeb.IconsTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Icons

  describe "proficiency/1" do
    test "renders each proficiency level as an accessibly named image" do
      for {proficiency, label, data_role} <- [
            {"Not enough data", "Not enough data", "no data proficiency icon"},
            {"Low", "Low proficiency", "beginning proficiency icon"},
            {"Medium", "Medium proficiency", "growing proficiency icon"},
            {"High", "High proficiency", "establishing proficiency icon"}
          ] do
        html = render_component(&Icons.proficiency/1, %{proficiency: proficiency})

        assert html =~ ~s(role="img")
        assert html =~ ~s(aria-label="#{label}")
        assert html =~ ~s(data-role="#{data_role}")
      end
    end
  end

  describe "world/1" do
    test "renders as a decorative icon with a stable data selector" do
      html = render_component(&Icons.world/1, %{})

      assert html =~ ~s(data-role="world icon")
      assert html =~ ~s(aria-hidden="true")
      refute html =~ ~s( role="world icon")
    end
  end
end
