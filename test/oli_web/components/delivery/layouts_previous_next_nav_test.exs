defmodule OliWeb.Components.Delivery.LayoutsPreviousNextNavTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.Layouts

  describe "previous_next_nav/1" do
    test "renders desktop title rows with shrinkable truncating spans" do
      page = %{
        "id" => "1",
        "slug" => "long-title-page",
        "type" => "page",
        "level" => "3",
        "title" => "A very long page title that should truncate in the section delivery bottom bar",
        "graded" => "false"
      }

      html =
        render_component(&Layouts.previous_next_nav/1, %{
          current_page: %{"id" => "99"},
          previous_page: page,
          next_page: page,
          section_slug: "section-slug",
          pages_progress: %{},
          request_path: "/sections/section-slug/page/long-title-page",
          selected_view: "gallery"
        })

      assert html =~
               ~s(class="hidden lg:flex grow shrink basis-0 min-w-0 h-10 justify-start items-center z-10")

      assert html =~
               ~s(class="hidden sm:flex flex-row gap-x-1 justify-start items-center grow shrink basis-0 w-0 flex-1 min-w-0 dark:text-white text-xs font-normal overflow-hidden whitespace-nowrap")

      assert html =~
               ~s(class="block w-0 min-w-0 flex-1 overflow-hidden text-ellipsis whitespace-nowrap")

      assert html =~
               ~s(class="hidden lg:flex grow shrink basis-0 min-w-0 h-10 justify-end items-center z-10")

      assert html =~
               ~s(class="hidden sm:flex flex-row gap-x-1 justify-end items-center grow shrink basis-0 w-0 flex-1 min-w-0 text-right dark:text-white text-xs font-normal overflow-hidden whitespace-nowrap")
    end
  end
end
