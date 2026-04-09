defmodule OliWeb.Components.DesignTokens.Primitives.ButtonTest do
  use OliWeb.ConnCase, async: true
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Icons

  describe "button/1" do
    test "uses primary small defaults when variant and size are omitted" do
      html =
        render_component(fn assigns ->
          ~H"""
          <Button.button>
            Save
          </Button.button>
          """
        end)

      assert html =~ "Save"
      assert html =~ "bg-Fill-Buttons-fill-primary"
      assert html =~ "h-8"
      refute html =~ "disabled"
    end

    test "renders icon slots" do
      html =
        render_component(fn assigns ->
          ~H"""
          <Button.button variant={:primary}>
            <:icon_left>
              <Icons.chevron_right class="h-4 w-4 stroke-current" />
            </:icon_left>
            Send Emails
          </Button.button>
          """
        end)

      assert html =~ "Send Emails"
      assert html =~ "stroke-current"
    end

    test "derives title and aria-label automatically for truncate" do
      html =
        render_component(fn assigns ->
          ~H"""
          <Button.button text_behavior={:truncate}>
            Save changes for all selected students
          </Button.button>
          """
        end)

      assert html =~ ~s(title="Save changes for all selected students")
      assert html =~ ~s(aria-label="Save changes for all selected students")
      assert html =~ "text-ellipsis"
    end

    test "close variant defaults aria-label and title to Close" do
      html = render_component(&Button.button/1, %{variant: :close})

      assert html =~ ~s(aria-label="Close")
      assert html =~ ~s(title="Close")
      assert html =~ "cursor-pointer"
    end

    test "renders a navigate link when navigate is provided" do
      html =
        render_component(fn assigns ->
          ~H"""
          <Button.button navigate="/sections/demo/student_dashboard/1/content">
            View Profile
          </Button.button>
          """
        end)

      assert html =~ ~s(href="/sections/demo/student_dashboard/1/content")
      assert html =~ "View Profile"
      refute html =~ ~s(type="button")
    end

    test "renders a patch link when patch is provided" do
      html =
        render_component(fn assigns ->
          ~H"""
          <Button.button patch="/sections/demo/instructor_dashboard/insights/dashboard?tile_support[bucket]=struggling">
            Filter
          </Button.button>
          """
        end)

      assert html =~
               ~s(href="/sections/demo/instructor_dashboard/insights/dashboard?tile_support[bucket]=struggling")

      assert html =~ "Filter"
      refute html =~ ~s(type="button")
    end

    test "raises when more than one link destination is provided" do
      assert_raise ArgumentError, ~r/accepts only one of :href, :navigate, or :patch/, fn ->
        render_component(fn assigns ->
          ~H"""
          <Button.button href="/a" navigate="/b">
            Broken
          </Button.button>
          """
        end)
      end
    end
  end
end
