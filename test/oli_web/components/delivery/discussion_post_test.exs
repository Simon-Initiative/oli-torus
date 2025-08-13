defmodule OliWeb.Components.Delivery.DiscussionPostTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.DiscussionPost

  describe "render/1" do
    test "renders discussion post with title" do
      assigns = %{
        title: "Test Discussion",
        last_posts: [],
        section_slug: "test-section"
      }

      html = render_component(&DiscussionPost.render/1, assigns)

      assert html =~ "Test Discussion"
      assert html =~ "There are no posts to show"
    end

    test "renders posts when available" do
      posts = [
        %{
          id: 1,
          title: "Post 1",
          user_name: "John Doe",
          content: %{message: "This is the first post"},
          updated_at: ~N[2024-01-15 10:00:00],
          slug: "post-1"
        },
        %{
          id: 2,
          title: "Post 2",
          user_name: "Jane Smith",
          content: %{message: "This is the second post"},
          updated_at: ~N[2024-01-16 11:00:00],
          slug: "post-2"
        }
      ]

      assigns = %{
        title: "Test Discussion",
        last_posts: posts,
        section_slug: "test-section"
      }

      html = render_component(&DiscussionPost.render/1, assigns)

      assert html =~ "Test Discussion"
      assert html =~ "Post 1"
      assert html =~ "Post 2"
      assert html =~ "John Doe"
      assert html =~ "Jane Smith"
      assert html =~ "This is the first post"
      assert html =~ "This is the second post"
      refute html =~ "There are no posts to show"
    end

    test "renders with correct styling classes" do
      assigns = %{
        title: "Test Discussion",
        last_posts: [],
        section_slug: "test-section"
      }

      html = render_component(&DiscussionPost.render/1, assigns)

      # Check for expected CSS classes
      assert html =~ "bg-white"
      assert html =~ "dark:bg-gray-800"
      assert html =~ "shadow"
      assert html =~ "mt-7"
      assert html =~ "py-6"
      assert html =~ "px-7"
      assert html =~ "font-normal"
      assert html =~ "text-base"
    end

    test "renders post links correctly" do
      posts = [
        %{
          id: 1,
          title: "Test Post",
          user_name: "John Doe",
          content: %{message: "Test message"},
          updated_at: ~N[2024-01-15 10:00:00],
          slug: "test-post"
        }
      ]

      assigns = %{
        title: "Test Discussion",
        last_posts: posts,
        section_slug: "test-section"
      }

      html = render_component(&DiscussionPost.render/1, assigns)

      # Check for link structure
      assert html =~ "href="
      assert html =~ "/sections/test-section/page/test-post"
      assert html =~ "text-delivery-primary"
      assert html =~ "hover:text-delivery-primary"
    end

    test "renders empty state when no posts" do
      assigns = %{
        title: "Test Discussion",
        last_posts: [],
        section_slug: "test-section"
      }

      html = render_component(&DiscussionPost.render/1, assigns)

      assert html =~ "There are no posts to show"
      assert html =~ "bg-white"
      assert html =~ "dark:bg-gray-800"
      assert html =~ "px-7"
      assert html =~ "py-4"
    end

    test "renders with dark mode support" do
      assigns = %{
        title: "Test Discussion",
        last_posts: [],
        section_slug: "test-section"
      }

      html = render_component(&DiscussionPost.render/1, assigns)

      # Check dark mode classes
      assert html =~ "dark:bg-gray-800"
    end

    test "renders post with relative date" do
      posts = [
        %{
          id: 1,
          title: "Test Post",
          user_name: "John Doe",
          content: %{message: "Test message"},
          updated_at: ~N[2024-01-15 10:00:00],
          slug: "test-post"
        }
      ]

      assigns = %{
        title: "Test Discussion",
        last_posts: posts,
        section_slug: "test-section"
      }

      html = render_component(&DiscussionPost.render/1, assigns)

      # Should include date formatting
      assert html =~ "font-medium"
      assert html =~ "text-sm"
    end
  end
end
