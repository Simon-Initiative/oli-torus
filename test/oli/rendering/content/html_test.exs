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
               ~r/<img.*src="https:\/\/upload.wikimedia.org\/wikipedia\/commons\/thumb\/f\/f9\/Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg\/480px-Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg" data-point-marker="1856577103" \/>/

      assert rendered_html_string =~
               ~r/<figcaption.*>John Trumbull&#39;s &lt;b&gt;Declaration of Independence&lt;\/b&gt;,/

      assert rendered_html_string =~
               "<p data-point-marker=\"2652513352\">The American colonials proclaimed &quot;no taxation without representation"

      assert rendered_html_string =~
               "<a class=\"internal-link\" href=\"/sections/some_section/lesson/page_two\">Page Two</a>"

      assert rendered_html_string =~
               "<a class=\"external-link\" href=\"https://en.wikipedia.org/wiki/Stamp_Act_Congress\" target=\"_blank\" rel=\"noreferrer\">Stamp Act Congress</a>"

      assert rendered_html_string =~ "<h3>1651–1748: Early seeds</h3>"

      assert rendered_html_string =~
               "<ol class=\"list-inside pl-2\"><li data-point-marker=\"1896247178\">one</li>\n<li data-point-marker=\"1896247178\"><em>two</em></li>\n<li data-point-marker=\"1896247178\"><em><strong>three</strong></em></li>\n</ol>"

      assert rendered_html_string =~
               "<ul class=\"list-inside pl-2\"><li data-point-marker=\"18868465\">alpha</li>\n<li data-point-marker=\"18868465\">beta</li>\n<li data-point-marker=\"18868465\">gamma</li>\n</ul>"

      assert rendered_html_string =~
               ~r/<div data-react-class="Components.YoutubePlayer"/

      assert rendered_html_string =~
               "<pre><code class=\"torus-code language-python\" data-point-marker=\"4076323894\">import fresh-pots</code></pre>"

      assert rendered_html_string =~
               ~r/<iframe class=".*"  allowfullscreen src="https:\/\/www.wikipedia.org" data-point-marker="1713634991"><\/iframe>/

      assert rendered_html_string =~ "<span class=\"callout-block\">a richtext callout</span>"

      assert rendered_html_string =~
               "<span class=\"formula\"><mrow><mi>a</mi><mo>+</mo><mi>b</mi></mrow></span>"

      assert rendered_html_string =~
               "<span class=\"formula\" data-point-marker=\"169365460\">\\[x^2 + y^2 = z^2\\]</span>"

      assert rendered_html_string =~
               "<span class=\"callout-inline\">a richtext inline callout</span>"

      assert rendered_html_string =~
               "<span class=\"formula-inline\"><mrow><mi>a</mi><mo>+</mo><mi>b</mi></mrow></span>"

      assert rendered_html_string =~ "<span class=\"formula-inline\">\\(x^2 + y^2 = z^2\\)</span>"

      assert rendered_html_string =~
               "<div class=\"dialog-content\"><p>Hello Speaker 2</p>\n</div>"

      assert rendered_html_string =~
               "<div class=\"dialog-content\"><p>Hello Speaker 1</p>\n</div>"

      assert rendered_html_string =~
               "<div class=\"dialog-speaker\" ><img src=\"https://www.example.com/image.png\" class=\"img-fluid speaker-portrait\"/><div class=\"speaker-name\">Speaker 2</div></div>"

      assert rendered_html_string =~
               "<div class='figure' data-point-marker=\"169365463\"><figure><figcaption><p>Figure Title</p>\n</figcaption><div class='figure-content'><p>Figure Content</p>\n</div></figure></div>"

      assert rendered_html_string =~
               "<div class=\"conjugation\" data-point-marker=\"169365461\"><div class=\"title\">My Term</div><div class=\"term\">El Verbo<span class='pronunciation'><p>my pronunciation</p>\n</span>\n</div><figure class=\"figure embed-responsive\"><div class=\"figure-content\"><table class='table-bordered '><tr><th>form</th>\n<th>meaning</th>\n</tr>\n<tr><td>my form</td>\n<td>my meaning</td>\n</tr>\n</table>\n</div></figure></div>"

      assert rendered_html_string =~
               "<span class=\"btn btn-primary command-button\" data-action=\"command-button\" data-target=\"3603298117\" data-message=\"startcuepoint=5.0;endcuepoint=10.0\">Play Intro</span>"
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

    test "renders content element with model field", %{author: author} do
      # This test expects that content with a "model" field should render the model contents
      content_with_model = %{
        "model" => [
          %{
            "children" => [
              %{
                "text" =>
                  "Among the following questions, which is a well-designed survey open-ended question?"
              }
            ],
            "id" => "c6929630baf84852849b804665882f90",
            "type" => "p"
          }
        ]
      }

      context = %Context{user: author}

      rendered_html = Content.render(context, content_with_model, Content.Html)
      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string()

      # Should render the paragraph content from the model field
      assert rendered_html_string =~
               "<p data-point-marker=\"c6929630baf84852849b804665882f90\">Among the following questions, which is a well-designed survey open-ended question?</p>"
    end
  end
end
