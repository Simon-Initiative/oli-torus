defmodule Oli.Delivery.Page.ModelPrunerTest do

  use ExUnit.Case, async: true

  alias Oli.Delivery.Page.ModelPruner

  test "prune/1 removes authoring key" do
    result = ModelPruner.prune(%{"authoring" => "answer", "stem" => "hi"})
    assert result == %{"stem" => "hi"}
  end

  test "prune/1 does nothing when authoring key isn't present" do
    result = ModelPruner.prune(%{"stem" => "hi"})
    assert result == %{"stem" => "hi"}
  end

end
