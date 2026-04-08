defmodule OliWeb.Products.ImagePreviewTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias OliWeb.Common.SessionContext
  alias OliWeb.Products.ImagePreview

  defp preview_ctx do
    %{SessionContext.init() | local_tz: "Etc/UTC"}
  end

  describe "preview wrappers" do
    test "my course preview reuses course_card without navigation side effects" do
      section =
        insert(:section,
          type: :blueprint,
          title: "Preview Biology",
          cover_image: "https://example.com/preview-cover.png"
        )
        |> Map.put(:instructors, [%{name: "Preview Instructor"}])
        |> Map.put(:progress, 65)

      html =
        render_component(&ImagePreview.preview_content/1, %{
          section: section,
          ctx: preview_ctx(),
          context: :my_course
        })

      assert html =~ "Preview Biology"
      assert html =~ "Preview Instructor"
      assert html =~ "Course Progress"
      assert html =~ "data-preview-mode=\"true\""
      refute html =~ ~s(href="/sections/)
    end

    test "course picker preview reuses card listing without selection behavior" do
      section =
        insert(:section,
          type: :blueprint,
          title: "Preview Biology",
          cover_image: nil
        )

      html =
        render_component(&ImagePreview.preview_content/1, %{
          section: section,
          ctx: preview_ctx(),
          context: :course_picker
        })

      assert html =~ "Select your source materials"
      assert html =~ "New Course Setup"
      assert html =~ "Select source"
      assert html =~ "Preview Biology"
      assert html =~ "/images/course_default.png"
      assert html =~ "data-preview-mode=\"true\""
      refute html =~ "phx-click="
    end

    test "student welcome preview reflects actual onboarding options" do
      section =
        insert(:section,
          type: :blueprint,
          title: "Preview Biology",
          cover_image: nil
        )
        |> Map.put(:required_survey_resource_id, nil)
        |> Map.put(:contains_explorations, false)

      html =
        render_component(&ImagePreview.preview_content/1, %{
          section: section,
          ctx: preview_ctx(),
          context: :student_welcome
        })

      assert html =~ "Welcome to Preview Biology!"
      refute html =~ "A short survey to help shape your learning experience"
      refute html =~ "Learning about the new ‘Exploration’ activities"
      assert html =~ "Go to course"
      assert html =~ "/images/course_default.png"
    end

    test "gallery renders the full uploaded image above the three shared runtime contexts" do
      section =
        insert(:section,
          type: :blueprint,
          title: "Preview Biology",
          cover_image: "https://example.com/preview-cover.png"
        )

      html =
        render_component(&ImagePreview.render/1, %{
          section: section,
          ctx: preview_ctx()
        })

      assert html =~ "id=\"current-product-img\""
      assert html =~ "data-preview-context=\"cover_image\""
      assert html =~ "data-preview-context=\"my_course\""
      assert html =~ "data-preview-context=\"course_picker\""
      assert html =~ "data-preview-context=\"student_welcome\""
      assert html =~ "aria-label=\"My Course\""
      assert html =~ "aria-label=\"Course Picker\""
      assert html =~ "aria-label=\"Student Welcome\""
    end

    test "modal renders the selected preview context with distinct labels" do
      section =
        insert(:section,
          type: :blueprint,
          title: "Preview Biology",
          cover_image: "https://example.com/preview-cover.png"
        )

      html =
        render_component(&ImagePreview.render/1, %{
          section: section,
          ctx: preview_ctx(),
          selected_context: :student_welcome,
          modal_open?: true
        })

      assert html =~ "Student Course Introduction"
      assert html =~ "aria-label=\"Show previous preview\""
      assert html =~ "aria-label=\"Show next preview\""
      assert html =~ "aria-label=\"Show previous preview\""
      assert html =~ "aria-label=\"Show next preview\""
      assert html =~ "stroke=\"#0080FF\""
      assert html =~ "circle cx=\"18\" cy=\"18\""
      refute html =~ ">Previous<"
      refute html =~ ">Next<"
      assert html =~ "aria-label=\"Student My Courses Page\""
      assert html =~ "aria-label=\"Instructor Course Builder\""
    end
  end
end
