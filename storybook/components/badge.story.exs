defmodule OliWeb.Storybook.Components.Badge do
  use PhoenixStorybook.Story, :component

  def function, do: &OliWeb.Components.Common.badge/1

  def variations do
    [
      %Variation{
        id: :default,
        description: "Default badge",
        slots: [
          """
          Default
          """,
        ]
      },
      %VariationGroup{
        id: :predefined_variants,
        description: "With predefined variants",
        variations:
          for variant <- ~w(primary info success warning danger)a do
            %Variation{
              id: variant,
              attributes: %{
                variant: variant
              },
              slots: [
                """
                #{Atom.to_string(variant)}
                """,
              ]
            }
          end
      },
    ]
  end
end
