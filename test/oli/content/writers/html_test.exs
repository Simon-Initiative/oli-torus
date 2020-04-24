defmodule Oli.Content.Writers.HTMLTest do
  use Oli.DataCase

  alias Oli.Content.Writers
  alias Oli.Content.Writers.Writer

  describe "HTML writer" do
    setup do
      author = author_fixture()

      %{author: author}
    end

    test "renders well-formed content properly", %{author: author} do
      {:ok, content} = read_json_file("./test/oli/content/writers/example_content.json")
      context = %Writers.Context{user: author}

      rendered_html = Writer.render(context, content, Writers.HTML)
      rendered_html_string = Phoenix.HTML.raw(rendered_html) |> Phoenix.HTML.safe_to_string

      assert rendered_html_string =~ "<h3>Introduction</h3>"
      assert rendered_html_string =~ "<img  style=\"display: block; max-height: 500px; margin-left: auto; margin-right: auto;\" src=\"https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg/480px-Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg\"/>"
      assert rendered_html_string =~ "<p>The American colonials proclaimed &quot;no taxation without representation"
      assert rendered_html_string =~ "<link href=\"https://en.wikipedia.org/wiki/Stamp_Act_Congress\">Stamp Act Congress</link>"
      assert rendered_html_string =~ "<h3>1651–1748: Early seeds</h3>"
      assert rendered_html_string =~ "<ol><li>one</li>\n<li><em>two</em></li>\n<li><em><strong>three</strong></em></li>\n</ol>"
      assert rendered_html_string =~ "<ul><li>alpha</li>\n<li>beta</li>\n<li>gamma</li>\n</ul>"
      assert rendered_html_string =~ "<iframe\n  id=\"fhdCslFcKFU\"\n  width=\"640\"\n  height=\"476\"\n  src=\"https://www.youtube.com/embed/fhdCslFcKFU\"\n  frameBorder=\"0\"\n  style=\"display: block; margin-left: auto; margin-right: auto;\"\n></iframe>"
      assert rendered_html_string =~ "<pre><code>import fresh-pots\n</pre></code>"
    end
  end
end
