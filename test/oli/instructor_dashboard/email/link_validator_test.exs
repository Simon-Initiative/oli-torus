defmodule Oli.InstructorDashboard.Email.LinkValidatorTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Email.LinkValidator

  defp link(href) do
    %{"type" => "a", "href" => href, "children" => [%{"text" => "x"}]}
  end

  defp wrap(node) do
    [%{"type" => "p", "children" => [node]}]
  end

  describe "valid_internal_path?/1" do
    test "rejects URL with scheme" do
      refute LinkValidator.valid_internal_path?("https://evil.com/x")
      refute LinkValidator.valid_internal_path?("http://x.com")
      refute LinkValidator.valid_internal_path?("javascript:xss")
      refute LinkValidator.valid_internal_path?("mailto:a@b.com")
    end

    test "rejects URL with host (protocol-relative)" do
      refute LinkValidator.valid_internal_path?("//evil.com/path")
    end

    test "rejects nil/non-binary" do
      refute LinkValidator.valid_internal_path?(nil)
      refute LinkValidator.valid_internal_path?(:atom)
      refute LinkValidator.valid_internal_path?(123)
    end

    test "rejects relative path with `..` traversal" do
      refute LinkValidator.valid_internal_path?("/foo/../admin")
    end

    test "rejects relative path not starting with `/`" do
      refute LinkValidator.valid_internal_path?("foo/bar")
    end

    test "rejects path that does not resolve to a router route" do
      refute LinkValidator.valid_internal_path?("/totally/fake/path")
    end

    test "accepts relative path that resolves to a real route" do
      assert LinkValidator.valid_internal_path?("/unauthorized")
    end

    test "rejects relative path with a query string (allowlist guard)" do
      refute LinkValidator.valid_internal_path?("/unauthorized?next=https://phishing.com")
    end

    test "rejects relative path with even a benign query string (conservative)" do
      refute LinkValidator.valid_internal_path?("/unauthorized?page=2")
    end

    test "accepts relative path with only a URI fragment" do
      assert LinkValidator.valid_internal_path?("/unauthorized#section-2")
    end

    test "accepts /course/link/:slug portable internal link format" do
      assert LinkValidator.valid_internal_path?("/course/link/welcome-page")
    end

    test "rejects /course/link path containing `..` traversal" do
      refute LinkValidator.valid_internal_path?("/course/link/../admin")
    end

    test "rejects /course/link path carrying a query string" do
      refute LinkValidator.valid_internal_path?("/course/link/welcome-page?next=x")
    end

    test "rejects /course/link with extra path segments (expects a single slug)" do
      refute LinkValidator.valid_internal_path?("/course/link/welcome-page/extra")
    end

    test "rejects /course/link with an empty slug" do
      refute LinkValidator.valid_internal_path?("/course/link/")
    end
  end

  describe "collect_unsafe_links/1" do
    test "returns empty for empty list" do
      assert [] == LinkValidator.collect_unsafe_links([])
    end

    test "returns empty when no link nodes present" do
      slate = [%{"type" => "p", "children" => [%{"text" => "plain"}]}]
      assert [] == LinkValidator.collect_unsafe_links(slate)
    end

    test "returns empty when only valid internal links present" do
      slate = wrap(link("/unauthorized"))
      assert [] == LinkValidator.collect_unsafe_links(slate)
    end

    test "treats /course/link/:slug as a safe internal link" do
      slate = wrap(link("/course/link/welcome-page"))
      assert [] == LinkValidator.collect_unsafe_links(slate)
    end

    test "collects single external link" do
      slate = wrap(link("https://evil.com"))
      assert ["https://evil.com"] == LinkValidator.collect_unsafe_links(slate)
    end

    test "collects link nested deeper in the tree" do
      slate = [
        %{
          "type" => "p",
          "children" => [
            %{
              "type" => "p",
              "children" => [link("https://evil.com")]
            }
          ]
        }
      ]

      assert ["https://evil.com"] == LinkValidator.collect_unsafe_links(slate)
    end

    test "deduplicates the same URL appearing multiple times" do
      slate = [
        %{
          "type" => "p",
          "children" => [link("https://evil.com"), link("https://evil.com")]
        }
      ]

      assert ["https://evil.com"] == LinkValidator.collect_unsafe_links(slate)
    end

    test "collects multiple distinct unsafe URLs" do
      slate = [
        %{
          "type" => "p",
          "children" => [link("https://evil.com"), link("javascript:x")]
        }
      ]

      result = LinkValidator.collect_unsafe_links(slate)
      assert "https://evil.com" in result
      assert "javascript:x" in result
    end

    test "ignores non-list input" do
      assert [] == LinkValidator.collect_unsafe_links(nil)
      assert [] == LinkValidator.collect_unsafe_links(%{})
      assert [] == LinkValidator.collect_unsafe_links("not a list")
    end

    test "filters out valid links and returns only unsafe ones" do
      slate = [
        %{
          "type" => "p",
          "children" => [
            link("/unauthorized"),
            link("https://evil.com")
          ]
        }
      ]

      assert ["https://evil.com"] == LinkValidator.collect_unsafe_links(slate)
    end
  end
end
