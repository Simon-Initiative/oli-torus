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
  end
end
