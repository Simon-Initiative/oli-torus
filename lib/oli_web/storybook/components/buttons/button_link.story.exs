defmodule OliWeb.Storybook.Components.Button do
  use PhoenixStorybook.Story, :component

  def function, do: &OliWeb.Components.Common.button_link/1

  def human_readable_size(size) do
    case size do
      :xs -> "Extra small"
      :sm -> "Small"
      :md -> "Medium"
      :lg -> "Large"
      :xl -> "Extra large"
      :custom -> "Custom"
    end
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default button",
        slots: [
          """
          Default
          """
        ]
      },
      %VariationGroup{
        id: :variants,
        description: "Variants",
        variations:
          for variant <- ~w(primary info success warning danger)a do
            %Variation{
              id: variant,
              attributes: %{
                text: "Variant",
                variant: variant
              },
              slots: [
                variant |> Atom.to_string() |> String.capitalize()
              ]
            }
          end
      },
      %VariationGroup{
        id: :sizes,
        description: "Sizes",
        variations:
          for size <- ~w(xs sm md lg xl custom)a do
            %Variation{
              id: size,
              attributes: %{
                text: "Size",
                variant: :primary,
                size: size
              },
              slots: [
                size |> human_readable_size()
              ]
            }
          end
      },
      %VariationGroup{
        id: :disabled,
        description: "Disabled",
        variations:
          for variant <- ~w(primary info success warning danger)a do
            %Variation{
              id: variant,
              attributes: %{
                text: "Disabled",
                variant: variant,
                disabled: true
              },
              slots: [
                variant |> Atom.to_string() |> String.capitalize()
              ]
            }
          end
      }
    ]
  end
end
