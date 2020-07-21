defmodule Oli.Content.Content.HtmlTest do
  use Oli.DataCase

  alias Oli.Rendering.Context
  alias Oli.Rendering.Content

  import ExUnit.CaptureLog

  describe "html content renderer" do
    setup do
      author = author_fixture()

      %{author: author}
    end

    test "renders well-formed content properly", %{author: author} do
      {:ok, content} = read_json_file("./test/oli/rendering/content/example_content.json")
      context = %Context{user: author}

      rendered_html = Content.render(context, content, Content.Html)
      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string

      assert rendered_html_string =~ "<h3>Introduction</h3>"
      assert rendered_html_string =~ "<img class=\"img-fluid img-thumbnail\" style=\"display: block; max-height: 500px; margin-left: auto; margin-right: auto;\" src=\"https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg/480px-Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg\"/>"
      assert rendered_html_string =~ "<p>The American colonials proclaimed &quot;no taxation without representation"
      assert rendered_html_string =~ "<a href=\"https://en.wikipedia.org/wiki/Stamp_Act_Congress\">Stamp Act Congress</a>"
      assert rendered_html_string =~ "<h3>1651–1748: Early seeds</h3>"
      assert rendered_html_string =~ "<ol><li>one</li>\n<li><em>two</em></li>\n<li><em><strong>three</strong></em></li>\n</ol>"
      assert rendered_html_string =~ "<ul><li>alpha</li>\n<li>beta</li>\n<li>gamma</li>\n</ul>"
      assert rendered_html_string =~ "<div class=\"embed-responsive embed-responsive-16by9 img-thumbnail\">\n  <iframe class=\"embed-responsive-item\" id=\"fhdCslFcKFU\" allowfullscreen src=\"https://www.youtube.com/embed/fhdCslFcKFU\">\n  </iframe>\n</div>"
      assert rendered_html_string =~ "<pre><code>import fresh-pots\n</code></pre>"
    end

    test "renders malformed content gracefully", %{author: author} do
      {:ok, content} = read_json_file("./test/oli/rendering/content/example_malformed_content.json")
      context = %Context{user: author}

      assert capture_log(fn ->
        rendered_html = Content.render(context, content, Content.Html)
        rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string

        # ensure malformed content doesnt prevent rendering over other valid content
        assert rendered_html_string =~ "<h3>Introduction</h3>"

        # render an error message for the malformed content element
        assert rendered_html_string =~ "<div class=\"content invalid\">Content element is invalid"
      end) =~ "Content element is invalid"
    end

    test "renders unsupported element properly", %{author: author} do
      {:ok, content} = read_json_file("./test/oli/rendering/content/example_unsupported_content.json")
      context = %Context{user: author}

      assert capture_log(fn ->
        rendered_html = Content.render(context, content, Content.Html)
        rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string

        # ensure unsupported content doesnt prevent rendering over other supported content
        assert rendered_html_string =~ "<h3>Introduction</h3>"

        # render an error message for the unsupported content element
        assert rendered_html_string =~ "<div class=\"content unsupported\">Content element type 'i-am-unsupported' is not supported"
      end) =~ "Content element is not supported"
    end

  end
end
