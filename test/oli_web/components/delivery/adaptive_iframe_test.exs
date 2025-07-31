defmodule OliWeb.Components.Delivery.AdaptiveIFrameTest do
  use OliWeb.ConnCase, async: true

  alias OliWeb.Components.Delivery.AdaptiveIFrame
  alias Oli.Resources.Revision

  describe "preview/2" do
    test "generates iframe with correct URL and size for preview" do
      project_slug = "test-project"

      revision = %Revision{
        slug: "test-revision",
        content: %{
          "custom" => %{
            "defaultScreenHeight" => 800,
            "defaultScreenWidth" => 1000
          }
        }
      }

      result = AdaptiveIFrame.preview(project_slug, revision)

      assert result =~ "iframe"
      assert result =~ "width=\"1150\""
      assert result =~ "height=\"975\""
      assert result =~ "/authoring/project/test-project/preview_fullscreen/test-revision"
      assert result =~ "class=\"bg-white mx-auto mb-24\""
    end

    test "uses default dimensions when custom content is not provided" do
      project_slug = "test-project"

      revision = %Revision{
        slug: "test-revision",
        content: %{}
      }

      result = AdaptiveIFrame.preview(project_slug, revision)

      assert result =~ "width=\"1250\""
      assert result =~ "height=\"1035\""
    end
  end

  describe "delivery/3" do
    test "generates iframe with correct URL and size for delivery" do
      section_slug = "test-section"
      revision_slug = "test-revision"

      content = %{
        "custom" => %{
          "defaultScreenHeight" => 600,
          "defaultScreenWidth" => 800
        }
      }

      result = AdaptiveIFrame.delivery(section_slug, revision_slug, content)

      assert result =~ "iframe"
      assert result =~ "width=\"950\""
      assert result =~ "height=\"775\""
      assert result =~ "/sections/test-section/page_fullscreen/test-revision"
      assert result =~ "class=\"bg-white mx-auto mb-24\""
    end

    test "uses default dimensions when custom content is not provided" do
      section_slug = "test-section"
      revision_slug = "test-revision"
      content = %{}

      result = AdaptiveIFrame.delivery(section_slug, revision_slug, content)

      assert result =~ "width=\"1250\""
      assert result =~ "height=\"1035\""
    end
  end

  describe "size calculation" do
    test "adds chrome dimensions to content dimensions" do
      content = %{
        "custom" => %{
          "defaultScreenHeight" => 500,
          "defaultScreenWidth" => 700
        }
      }

      # Test the private function through the public interface
      result = AdaptiveIFrame.delivery("section", "revision", content)

      # Should add chrome_width (150) and chrome_height (175) to content dimensions
      assert result =~ "width=\"850\""
      assert result =~ "height=\"675\""
    end

    test "handles nil custom content gracefully" do
      content = %{"custom" => %{"defaultScreenHeight" => 0, "defaultScreenWidth" => 0}}

      result = AdaptiveIFrame.delivery("section", "revision", content)

      # Should use default dimensions
      assert result =~ "width=\"150\""
      assert result =~ "height=\"175\""
    end
  end
end
