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
      context = %Context{user: author, section_slug: "some_section"}

      rendered_html = Content.render(context, content, Content.Html)
      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      assert rendered_html_string =~ "<h3>Introduction</h3>"

      assert rendered_html_string =~
               ~r/<img.*src="https:\/\/upload.wikimedia.org\/wikipedia\/commons\/thumb\/f\/f9\/Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg\/480px-Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg"\/>/

      assert rendered_html_string =~
               ~r/<figcaption.*>John Trumbull&#39;s &lt;b&gt;Declaration of Independence&lt;\/b&gt;,/

      assert rendered_html_string =~
               "<p>The American colonials proclaimed &quot;no taxation without representation"

      assert rendered_html_string =~
               "<a class=\"internal-link\" href=\"/sections/some_section/page/page_two\">Page Two</a>"

      assert rendered_html_string =~
               "<a class=\"external-link\" href=\"https://en.wikipedia.org/wiki/Stamp_Act_Congress\" target=\"_blank\">Stamp Act Congress</a>"

      assert rendered_html_string =~ "<h3>1651–1748: Early seeds</h3>"

      assert rendered_html_string =~
               "<ol><li>one</li>\n<li><em>two</em></li>\n<li><em><strong>three</strong></em></li>\n</ol>"

      assert rendered_html_string =~ "<ul><li>alpha</li>\n<li>beta</li>\n<li>gamma</li>\n</ul>"

      assert rendered_html_string =~
               ~r/<div class=".*">\s*<iframe.* src="https:\/\/www.youtube.com\/embed\/fhdCslFcKFU"><\/iframe>\s*<\/div>/

      assert rendered_html_string =~
               "<pre><code class=\"language-python\">import fresh-pots</code></pre>"

      assert rendered_html_string =~
               ~r/<iframe class=".*" allowfullscreen src="https:\/\/www.wikipedia.org"><\/iframe>/

      assert rendered_html_string =~ "<span class=\"callout-block\">a richtext callout</span>"

      assert rendered_html_string =~
               "<span class=\"formula\"><mrow><mi>a</mi><mo>+</mo><mi>b</mi></mrow></span>"

      assert rendered_html_string =~ "<span class=\"formula\">\\[x^2 + y^2 = z^2\\]</span>"

      assert rendered_html_string =~
               "<span class=\"callout-inline\">a richtext inline callout</span>"

      assert rendered_html_string =~
               "<span class=\"formula-inline\"><mrow><mi>a</mi><mo>+</mo><mi>b</mi></mrow></span>"

      assert rendered_html_string =~ "<span class=\"formula-inline\">\\(x^2 + y^2 = z^2\\)</span>"
    end

    test "renders malformed content gracefully", %{author: author} do
      {:ok, content} =
        read_json_file("./test/oli/rendering/content/example_malformed_content.json")

      context = %Context{user: author}

      assert capture_log(fn ->
               rendered_html = Content.render(context, content, Content.Html)

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               # ensure malformed content doesnt prevent rendering over other valid content
               assert rendered_html_string =~ "<h3>Introduction</h3>"

               # render an error message for the malformed content element
               assert rendered_html_string =~
                        "<div class=\"content invalid\">Content element is invalid"
             end) =~ "Content element is invalid"
    end

    test "renders unsupported element properly", %{author: author} do
      {:ok, content} =
        read_json_file("./test/oli/rendering/content/example_unsupported_content.json")

      context = %Context{user: author}

      assert capture_log(fn ->
               rendered_html = Content.render(context, content, Content.Html)

               rendered_html_string =
                 Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

               # ensure unsupported content doesnt prevent rendering over other supported content
               assert rendered_html_string =~ "<h3>Introduction</h3>"

               # render an error message for the unsupported content element
               assert rendered_html_string =~
                        "<div class=\"content unsupported\">Content element type 'i-am-unsupported' is not supported"
             end) =~ "Content element type is not supported"
    end
  end
end
