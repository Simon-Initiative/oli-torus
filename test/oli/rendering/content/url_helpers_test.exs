defmodule Oli.Rendering.Content.UrlHelpersTest do
  use ExUnit.Case, async: true

  alias Oli.Rendering.Content.UrlHelpers

  test "preview lesson paths encode path segments before appending query params" do
    assert UrlHelpers.preview_lesson_path("section/one", "quiz?draft=true", request_path: "/x") ==
             "/sections/section%2Fone/preview/lesson/quiz%3Fdraft%3Dtrue?request_path=%2Fx"
  end

  test "preview selection paths encode path segments before appending query params" do
    assert UrlHelpers.preview_selection_path("section#one", "quiz/page", "selection?1",
             return_to: "/sections/section/remix"
           ) ==
             "/sections/section%23one/preview/lesson/quiz%2Fpage/selection/selection%3F1?return_to=%2Fsections%2Fsection%2Fremix"
  end
end
