defmodule OliWeb.Components.Delivery.DiscussionBoardTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.DiscussionBoard

  describe "render/1" do
    test "renders discussion board with title" do
      assigns = %{
        last_posts_user: [],
        last_posts_section: [],
        section_slug: "test-section"
      }

      html = render_component(&DiscussionBoard.render/1, assigns)

      assert html =~ "Discussion Board"
      assert html =~ "Your Latest Discussion Activity"
      assert html =~ "All Discussion Activity"
    end

    test "renders with correct styling classes" do
      assigns = %{
        last_posts_user: [],
        last_posts_section: [],
        section_slug: "test-section"
      }

      html = render_component(&DiscussionBoard.render/1, assigns)

      assert html =~ "flex flex-col"
      assert html =~ "mt-4"
      assert html =~ "px-7"
      assert html =~ "sm:px-0"
      assert html =~ "text-xl"
      assert html =~ "font-normal"
    end

    test "render/1 passes correct props to DiscussionPost components" do
      assigns = %{
        last_posts_user: [
          %{
            id: 1,
            title: "User Post",
            user_name: "John Doe",
            content: %{message: "Test message"},
            updated_at: ~N[2024-01-15 10:00:00],
            slug: "user-post"
          }
        ],
        last_posts_section: [
          %{
            id: 2,
            title: "Section Post",
            user_name: "Jane Smith",
            content: %{message: "Another message"},
            updated_at: ~N[2024-01-16 10:00:00],
            slug: "section-post"
          }
        ],
        section_slug: "test-section"
      }

      html = render_component(&DiscussionBoard.render/1, assigns)

      assert html =~ "Discussion Board"
      assert html =~ "Your Latest Discussion Activity"
      assert html =~ "All Discussion Activity"
      assert html =~ "User Post"
      assert html =~ "Section Post"
    end
  end
end
