defmodule Oli.Content.Content.PlaintextTest do
  use Oli.DataCase

  alias Oli.Rendering.Context
  alias Oli.Rendering.Content

  describe "plaintext content renderer" do
    setup do
      author = author_fixture()

      %{author: author}
    end

    test "renders well-formed content properly", %{author: author} do
      {:ok, content} = read_json_file("./test/oli/rendering/content/example_content.json")
      context = %Context{user: author, section_slug: "some_section"}

      rendered_text =
        Content.render(context, content, Content.Plaintext)
        |> Phoenix.HTML.raw()
        |> Phoenix.HTML.safe_to_string()

      assert rendered_text =~ "Introduction"

      assert rendered_text =~ "a richtext callout"
      assert rendered_text =~ "a richtext inline callout"

      assert rendered_text =~
               "[Formula]: <mrow><mi>a</mi><mo>+</mo><mi>b</mi></mrow>"

      assert rendered_text =~ "[Formula]: x^2 + y^2 = z^2"
    end
  end
end
