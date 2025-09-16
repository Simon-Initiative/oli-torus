defmodule OliWeb.Components.Delivery.LTIExternalToolsTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.LTIExternalTools

  describe "lti_external_tool/1" do
    test "renders LTI external tool with basic attributes" do
      assigns = %{
        id: "tool-1",
        name: "Test Tool",
        login_url: "https://example.com/launch",
        launch_params: %{
          "user_id" => "123",
          "course_id" => "456"
        }
      }

      html = render_component(&LTIExternalTools.lti_external_tool/1, assigns)

      assert html =~ "Test Tool"
      assert html =~ "Launch Test Tool"
      assert html =~ "https://example.com/launch"
      assert html =~ "tool-content=tool-1"
    end

    test "renders form with hidden inputs for launch params" do
      assigns = %{
        id: "tool-1",
        name: "Test Tool",
        login_url: "https://example.com/launch",
        launch_params: %{
          "user_id" => "123",
          "course_id" => "456",
          "timestamp" => "1234567890"
        }
      }

      html = render_component(&LTIExternalTools.lti_external_tool/1, assigns)

      assert html =~ "form"
      assert html =~ "action=\"https://example.com/launch\""
      assert html =~ "method=\"POST\""
      assert html =~ "target=\"tool-content=tool-1\""
      assert html =~ "input type=\"hidden\""
      assert html =~ "name=\"user_id\""
      assert html =~ "value=\"123\""
      assert html =~ "name=\"course_id\""
      assert html =~ "value=\"456\""
      assert html =~ "name=\"timestamp\""
      assert html =~ "value=\"1234567890\""
    end

    test "renders iframe with correct attributes" do
      assigns = %{
        id: "tool-1",
        name: "Test Tool",
        login_url: "https://example.com/launch",
        launch_params: %{}
      }

      html = render_component(&LTIExternalTools.lti_external_tool/1, assigns)

      assert html =~ "iframe"
      assert html =~ "src=\"about:blank\""
      assert html =~ "name=\"tool-content=tool-1\""
      assert html =~ "class=\"tool_launch\""
      assert html =~ "allowfullscreen=\"allowfullscreen\""
      assert html =~ "webkitallowfullscreen=\"true\""
      assert html =~ "mozallowfullscreen=\"true\""
      assert html =~ "tabindex=\"0\""
      assert html =~ "title=\"Tool Content\""
      assert html =~ "style=\"height:100%;width:100%;\""
      assert html =~ "data-lti-launch=\"true\""
    end

    test "renders with correct styling classes" do
      assigns = %{
        id: "tool-1",
        name: "Test Tool",
        login_url: "https://example.com/launch",
        launch_params: %{}
      }

      html = render_component(&LTIExternalTools.lti_external_tool/1, assigns)

      # Check for expected CSS classes and styles
      assert html =~ "mt-3"
      assert html =~ "style=\"height: 600px\""
      assert html =~ "hide"
      assert html =~ "btn"
      assert html =~ "btn-primary"
    end

    test "renders button with correct text" do
      assigns = %{
        id: "tool-1",
        name: "Custom Tool Name",
        login_url: "https://example.com/launch",
        launch_params: %{}
      }

      html = render_component(&LTIExternalTools.lti_external_tool/1, assigns)

      assert html =~ "Launch Custom Tool Name"
    end

    test "renders with empty launch params" do
      assigns = %{
        id: "tool-1",
        name: "Test Tool",
        login_url: "https://example.com/launch",
        launch_params: %{}
      }

      html = render_component(&LTIExternalTools.lti_external_tool/1, assigns)

      assert html =~ "form"
      assert html =~ "iframe"
      # Should not have any hidden inputs since launch_params is empty
      refute html =~ "input type=\"hidden\""
    end

    test "renders with complex launch params" do
      assigns = %{
        id: "tool-1",
        name: "Test Tool",
        login_url: "https://example.com/launch",
        launch_params: %{
          "custom_param" => "custom_value",
          "another_param" => "another_value",
          "numeric_param" => "123"
        }
      }

      html = render_component(&LTIExternalTools.lti_external_tool/1, assigns)

      assert html =~ "name=\"custom_param\""
      assert html =~ "value=\"custom_value\""
      assert html =~ "name=\"another_param\""
      assert html =~ "value=\"another_value\""
      assert html =~ "name=\"numeric_param\""
      assert html =~ "value=\"123\""
    end
  end
end
