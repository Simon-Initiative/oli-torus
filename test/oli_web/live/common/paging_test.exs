defmodule OliWeb.Common.PagingTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Common.Paging

  test "the arrow buttons have accessible names" do
    doc =
      render_component(&Paging.render/1,
        id: "paging",
        total_count: 45,
        offset: 20,
        limit: 10,
        click: "page_change"
      )
      |> Floki.parse_document!()

    for name <- ["First page", "Previous page", "Next page", "Last page"] do
      assert [_] = Floki.find(doc, ~s(nav button[aria-label="#{name}"])), name
    end

    assert doc
           |> Floki.find(~s(nav button[aria-label="Next page"]))
           |> Floki.attribute("phx-value-offset") == ["30"]

    assert doc
           |> Floki.find("nav button")
           |> Enum.map(&Floki.text/1)
           |> Enum.map(&String.trim/1)
           |> Enum.filter(&(&1 != "")) == ["1", "2", "3", "4", "5"]
  end
end
