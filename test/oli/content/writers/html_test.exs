defmodule Oli.Content.Writers.HTMLTest do
  use Oli.DataCase

  alias Oli.Content.Writers
  alias Oli.Content.Writers.Writer

  describe "HTML writer content render" do
    setup do
      author = author_fixture()

      %{author: author}
    end

    test "content", %{author: author} do
      {:ok, content} = read_json_file("./test/oli/content/writers/example_content.json")
      context = %Writers.Context{user: author}

      IO.inspect Writer.render(context, content, Writers.HTML)
    end
  end
end
