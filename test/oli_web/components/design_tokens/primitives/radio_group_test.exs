defmodule OliWeb.Components.DesignTokens.Primitives.RadioGroupTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.DesignTokens.Primitives.RadioGroup

  describe "radio_group/1" do
    test "renders a fieldset with a legend and one labelled native radio per option, only the selected one checked" do
      document =
        %{
          id: "tool-availability",
          name: "availability",
          legend: "Availability",
          options: [%{value: "public", label: "Public"}, %{value: "private", label: "Private"}],
          value: "private"
        }
        |> render_radio_group()
        |> Floki.parse_fragment!()

      assert [fieldset] = Floki.find(document, "fieldset#tool-availability")
      assert fieldset |> Floki.find("legend") |> Floki.text() |> String.trim() == "Availability"

      radios = Floki.find(fieldset, "input[type='radio']")

      assert Enum.flat_map(radios, &Floki.attribute(&1, "name")) == [
               "availability",
               "availability"
             ]

      assert Enum.flat_map(radios, &Floki.attribute(&1, "value")) == ["public", "private"]

      for {radio, label} <- Enum.zip(radios, ["Public", "Private"]) do
        assert [id] = Floki.attribute(radio, "id")
        assert [label_element] = Floki.find(fieldset, "label[for='#{id}']")
        assert label_element |> Floki.text() |> String.trim() == label
      end

      assert [checked] = Floki.find(fieldset, "input[type='radio'][checked]")
      assert Floki.attribute(checked, "value") == ["private"]
    end
  end

  defp render_radio_group(assigns) do
    render_component(&RadioGroup.radio_group/1, assigns)
  end
end
