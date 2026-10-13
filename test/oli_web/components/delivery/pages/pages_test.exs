defmodule OliWeb.Components.Delivery.PagesTest do
  use ExUnit.Case, async: true

  alias OliWeb.Components.Delivery.Pages

  test "an activity without attempts has no measured average score" do
    assert is_nil(Pages.normalize_activity_score(0, 0.0))
    assert is_nil(Pages.normalize_activity_score(nil, 0.0))
  end

  test "an attempted score of zero remains measured" do
    assert Pages.normalize_activity_score(1, 0.0) == 0.0
  end
end
