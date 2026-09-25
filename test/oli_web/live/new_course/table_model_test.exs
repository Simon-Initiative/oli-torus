defmodule OliWeb.Delivery.NewCourse.TableModelTest do
  use ExUnit.Case, async: true

  alias OliWeb.Delivery.NewCourse.TableModel

  describe "tag_variant/1" do
    test "returns :template for a product/blueprint source" do
      assert TableModel.tag_variant(%{type: :blueprint}) == :template
    end

    test "returns :my_section for a course/enrollable source" do
      assert TableModel.tag_variant(%{type: :enrollable}) == :my_section
    end

    test "returns nil for an ordinary project/publication source" do
      assert TableModel.tag_variant(%{project: %{title: "A project"}}) == nil
    end

    test "returns nil for any other unrecognized source shape instead of raising" do
      assert TableModel.tag_variant(%{type: :something_else}) == nil
      assert TableModel.tag_variant(%{}) == nil
    end
  end
end
