defmodule Oli.Content.Page.HtmlTest do
  use Oli.DataCase

  alias Oli.Rendering.Context
  alias Oli.Rendering.Page
  alias Oli.Rendering.Activity.ActivitySummary

  import ExUnit.CaptureLog

  describe "html page renderer" do
    setup do
      author = author_fixture()

      %{author: author}
    end

    test "renders well-formed page properly", %{author: author} do
      {:ok, page_content} = read_json_file("./test/oli/rendering/page/example_page.json")

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{}",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        },
        2 => %ActivitySummary{
          id: 2,
          graded: false,
          state: "{}",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-check-all-that-apply-delivery",
          authoring_element: "oli-check-all-that-apply-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      context = %Context{user: author, activity_map: activity_map}
      rendered_html = Page.render(context, page_content, Page.Html)
      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~ "<h3>Introduction</h3>"
      assert rendered_html_string =~ "<oli-multiple-choice-delivery"
      assert rendered_html_string =~ "<oli-check-all-that-apply-delivery"

      assert rendered_html_string =~
               "<div class=\"flex content-purpose-label\"><div class=\"flex-grow-1\">Learn by doing"

      assert rendered_html_string =~
               "The American Revolution was a colonial revolt which occurred between 1765 and 1783"
    end

    test "renders malformed page gracefully", %{author: author} do
      invalid_page_content = %{
        "this-is-not-valid" =>
          "page content should contain a model consisting of a list of elements"
      }

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{}",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      assert capture_log(fn ->
               context = %Context{user: author, activity_map: activity_map}
               rendered_html = Page.render(context, invalid_page_content, Page.Html)

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               # render an error message for the invalid page
               assert rendered_html_string =~
                        "<div class=\"alert alert-danger\">Page is invalid"
             end) =~ "Page is invalid"
    end

    test "renders unsupported page items gracefully", %{author: author} do
      {:ok, page_content} =
        read_json_file("./test/oli/rendering/page/example_malformed_page.json")

      activity_map = %{
        1 => %ActivitySummary{
          id: 1,
          graded: false,
          state: "{}",
          model:
            "{ \"choices\": [ \"A\", \"B\", \"C\", \"D\" ], \"feedback\": [ \"A\", \"B\", \"C\", \"D\" ], \"stem\": \"\"}",
          delivery_element: "oli-multiple-choice-delivery",
          authoring_element: "oli-multiple-choice-authoring",
          script: "./authoring-entry.ts",
          attempt_guid: "12345",
          lifecycle_state: :active
        }
      }

      assert capture_log(fn ->
               context = %Context{user: author, activity_map: activity_map}
               rendered_html = Page.render(context, page_content, Page.Html)

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               # ensure unsupported page item doesnt prevent rendering over other valid items
               assert rendered_html_string =~ "<h3>Introduction</h3>"
               assert rendered_html_string =~ "<oli-multiple-choice-delivery"

               # render an error message for the unsupported page item
               assert rendered_html_string =~
                        "<div class=\"alert alert-danger\">Element type 'some-unsupported-page-item' is not supported"
             end) =~ "Element type 'some-unsupported-page-item' is not supported"
    end

    test "handles missing language attributes on codeblocks gracefully", %{author: author} do
      robustnesss_test(
        author,
        "./test/oli/rendering/page/missing_language.json",
        "this is text from the code block"
      )
    end

    test "handles links that are missing hrefs", %{author: author} do
      robustnesss_test(
        author,
        "./test/oli/rendering/page/link_missing_href.json",
        "website"
      )
    end

    test "does not display images without a src", %{author: author} do
      {:ok, page_content} = read_json_file("./test/oli/rendering/page/image_missing_src.json")

      assert capture_log(fn ->
               context = %Context{user: author, activity_map: %{}}
               rendered_html = Page.render(context, page_content, Page.Html)

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               assert rendered_html_string ==
                        "<div class=\"content\" ><p>some specific content</p>\n</div>"
             end)
    end

    test "does not display youtube videos without a src", %{author: author} do
      {:ok, page_content} = read_json_file("./test/oli/rendering/page/youtube_missing_src.json")

      assert capture_log(fn ->
               context = %Context{user: author, activity_map: %{}}
               rendered_html = Page.render(context, page_content, Page.Html)

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               assert rendered_html_string ==
                        "<div class=\"content\" ><p>some specific content</p>\n</div>"
             end)
    end

    test "renders malformed audio robustly", %{author: author} do
      robustnesss_test(
        author,
        "./test/oli/rendering/page/audio_missing_src.json",
        "some specific content"
      )
    end

    test "renders malformed iframe robustly", %{author: author} do
      robustnesss_test(
        author,
        "./test/oli/rendering/page/iframe_missing_src.json",
        "some specific content"
      )
    end

    defp robustnesss_test(author, file, to_check) do
      {:ok, page_content} = read_json_file(file)

      assert capture_log(fn ->
               context = %Context{user: author, activity_map: %{}}
               rendered_html = Page.render(context, page_content, Page.Html)

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               # ensure unsupported page item doesnt prevent rendering over other valid items
               assert rendered_html_string =~ to_check
             end) =~ "Malformed content element"
    end
  end
end
