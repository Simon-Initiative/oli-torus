defmodule OliWeb.Delivery.Student.Lesson.Components.OutlineComponentTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests

  alias OliWeb.Delivery.Student.Lesson.Components.OutlineComponent
  alias Oli.Resources.ResourceType

  describe "outline component" do
    setup do
      # Define a sample hierarchy to use in tests
      hierarchy = %{
        "resource_id" => 0,
        "title" => "Course Root",
        "children" => [
          %{
            "id" => 1,
            "resource_id" => 1,
            "title" => "Introduction",
            "resource_type_id" => ResourceType.id_for_container(),
            "numbering" => %{"level" => 1, "index" => 1},
            "children" => [
              %{
                "id" => 11,
                "resource_id" => 11,
                "title" => "Lesson 1",
                "resource_type_id" => ResourceType.id_for_page(),
                "slug" => "lesson_1",
                "numbering" => %{"level" => 2, "index" => 1},
                "section_resource" => %{purpose: :foundation},
                "graded" => true
              },
              %{
                "id" => 12,
                "resource_id" => 12,
                "title" => "Lesson 2",
                "resource_type_id" => ResourceType.id_for_page(),
                "slug" => "lesson_2",
                "numbering" => %{"level" => 2, "index" => 2},
                "section_resource" => %{purpose: :foundation}
              }
            ]
          },
          %{
            "id" => 2,
            "resource_id" => 2,
            "title" => "Main Concepts",
            "resource_type_id" => ResourceType.id_for_container(),
            "numbering" => %{"level" => 1, "index" => 2},
            "children" => [
              %{
                "id" => 21,
                "resource_id" => 21,
                "title" => "Lesson 3",
                "resource_type_id" => ResourceType.id_for_page(),
                "numbering" => %{"level" => 2, "index" => 1},
                "slug" => "lesson_3",
                "section_resource" => %{purpose: :application}
              }
            ]
          },
          %{
            "id" => 3,
            "resource_id" => 3,
            "title" => "Top Level Lesson",
            "resource_type_id" => ResourceType.id_for_page(),
            "numbering" => %{"level" => 1, "index" => 3},
            "graded" => true,
            "slug" => "top_level_lesson",
            "section_resource" => %{purpose: :application}
          }
        ]
      }

      component_params = %{
        hierarchy: hierarchy,
        section_slug: "section_slug",
        selected_view: :gallery,
        page_resource_id: 11,
        section_id: 1,
        user_id: 1
      }

      {:ok, component_params: component_params}
    end

    test "renders the outline hierarchy with top-level items", %{
      conn: conn,
      component_params: component_params
    } do
      {:ok, lcd, _html} = live_component_isolated(conn, OutlineComponent, component_params)

      # Unit 1
      assert lcd |> element("#outline_item_1 div[role='title']") |> render() =~ "Unit 1"
      assert lcd |> element("#outline_item_1 div[role='title']") |> render() =~ "Introduction"

      # Renders top level ancestor progress bar
      assert lcd
             |> element("#outline_item_1 div[role='progress bar']")
             |> render() =~ "0%"

      # Unit 2
      assert lcd |> element("#outline_item_2 div[role='title']") |> render() =~ "Unit 2"
      assert lcd |> element("#outline_item_2 div[role='title']") |> render() =~ "Main Concepts"

      # Top Level Lesson
      assert lcd |> element("#outline_item_3 div[role='title']") |> render() =~ "Top Level Lesson"

      assert lcd |> element("#outline_item_3 div[role='page icon']") |> render() =~
               "text-exploration"

      assert lcd |> element("#outline_item_3 div[role='index']") |> render() =~ "3"
    end

    test "expands and collapses an item to show or hide its children", %{
      conn: conn,
      component_params: component_params
    } do
      {:ok, lcd, _html} = live_component_isolated(conn, OutlineComponent, component_params)

      # Ensure children are not visible initially
      refute lcd |> has_element?("#outline_item_11")
      refute lcd |> has_element?("#outline_item_12")

      # Expand item "1" to show children
      lcd
      |> element("[phx-click='expand_item'][phx-value-item_id='1']")
      |> render_click()

      # Ensure children are visible after expanding
      assert lcd |> element("#outline_item_11 div[role='title']") |> render() =~ "Lesson 1"

      assert lcd |> element("#outline_item_11 div[role='page icon']") |> render() =~
               "text-checkpoint"

      assert lcd |> element("#outline_item_12 div[role='title']") |> render() =~ "Lesson 2"

      # It is a practice page so it has no icon
      assert lcd |> has_element?("#outline_item_12 div[role='no icon']")

      # Collapse item "1" to hide children again
      lcd
      |> element("[phx-click='expand_item'][phx-value-item_id='1']")
      |> render_click()

      # Ensure children are hidden after collapsing
      refute lcd |> has_element?("#outline_item_11")
      refute lcd |> has_element?("#outline_item_12")
    end
  end
end
