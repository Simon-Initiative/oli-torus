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

  describe "student navigation and status icons" do
    test "render as decorative icons with stable data selectors" do
      for {component, attrs, data_role, old_role} <- [
            {&Icons.home/1, %{is_active: false}, "home icon", "home icon"},
            {&Icons.home/1, %{is_active: true}, "active home icon", "active home icon"},
            {&Icons.learn/1, %{is_active: false}, "learn icon", "learn icon"},
            {&Icons.schedule/1, %{is_active: false}, "schedule icon", "schedule icon"},
            {&Icons.discussions/1, %{is_active: false}, "discussions icon", "discussions icon"},
            {&Icons.explorations/1, %{is_active: false}, "explorations icon",
             "explorations icon"},
            {&Icons.assignments/1, %{is_active: false}, "assignments icon", "assignments icon"},
            {&Icons.practice/1, %{is_active: false}, "practice icon", "practice icon"},
            {&Icons.clock/1, %{}, "clock icon", "clock icon"},
            {&Icons.hidden/1, %{}, "hidden icon", "hidden icon"},
            {&Icons.timezone_world/1, %{}, "timezone world icon", "timezone world icon"},
            {&Icons.star/1, %{}, "star icon", "star icon"},
            {&Icons.plus/1, %{}, "plus icon", "plus icon"},
            {&Icons.asterisk/1, %{}, "asterisk icon", "asterisk icon"}
          ] do
        html = render_component(component, attrs)

        assert html =~ ~s(data-role="#{data_role}")
        assert html =~ ~s(aria-hidden="true")
        refute html =~ ~s( role="#{old_role}")
      end
    end
  end
end
