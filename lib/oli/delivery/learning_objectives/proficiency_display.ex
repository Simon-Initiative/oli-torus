defmodule Oli.Delivery.LearningObjectives.ProficiencyDisplay do
  @moduledoc """
  Centralizes student-facing proficiency metadata for learning objectives.

  Maps persisted proficiency values to delivery labels, icons, descriptions,
  display order, and shared delivery styling. Rendering details such as HTML,
  HEEx components, and caller-specific classes stay in the caller.
  """

  @default_label "Not Enough Information"
  @levels ["Not enough data", "Low", "Medium", "High"]

  @type t :: %{
          level: :not_enough_information | :beginning | :growing | :strong,
          source_value: String.t() | nil,
          id_key: String.t(),
          label: String.t(),
          label_lines: [String.t()],
          icon: :empty_pot | :seed | :sprout | :tree,
          description: String.t()
        }

  @spec default_label() :: String.t()
  def default_label, do: @default_label

  @spec levels() :: [String.t()]
  def levels, do: @levels

  @spec shared_card_styles_for(String.t() | nil) :: map()
  def shared_card_styles_for("High") do
    %{
      icon_class: "h-6 w-6 shrink-0 text-Text-text-accent-green",
      card_class: "justify-start bg-Fill-Chip-Green px-[17px] pt-[25px]",
      content_class: "w-[126px]",
      order_class: "order-3 md:order-4"
    }
  end

  def shared_card_styles_for("Medium") do
    %{
      icon_class: "h-6 w-6 shrink-0 text-Icon-icon-accent-purple",
      card_class: "justify-start bg-Fill-Accent-fill-accent-purple px-[15px] pt-[28px]",
      content_class: "w-[130px]",
      order_class: "order-4 md:order-3"
    }
  end

  def shared_card_styles_for("Low") do
    %{
      icon_class: "h-6 w-6 shrink-0 text-Icon-icon-accent-orange",
      card_class: "justify-start bg-Fill-Accent-fill-accent-orange/70 px-6 pt-[23px]",
      content_class: "w-[112px]",
      order_class: "order-2"
    }
  end

  def shared_card_styles_for(_) do
    %{
      icon_class: "h-6 w-6 shrink-0",
      card_class: "justify-start bg-Fill-Chip-Gray px-4 pt-[31px] md:bg-Table-table-row-1",
      content_class: "w-32",
      order_class: "order-1"
    }
  end

  @spec display_for(String.t() | nil) :: t()
  def display_for("High") do
    %{
      level: :strong,
      source_value: "High",
      id_key: "strong",
      label: "Strong Proficiency",
      label_lines: ["Strong", "Proficiency"],
      icon: :tree,
      description:
        "You’re likely to successfully apply this learning objective in different contexts. Continue applying this learning objective as you progress through the course."
    }
  end

  def display_for("Medium") do
    %{
      level: :growing,
      source_value: "Medium",
      id_key: "growing",
      label: "Growing Proficiency",
      label_lines: ["Growing", "Proficiency"],
      icon: :sprout,
      description:
        "You’ve clearly applied this learning objective. Continue practicing across more opportunities to strengthen your consistency."
    }
  end

  def display_for("Low") do
    %{
      level: :beginning,
      source_value: "Low",
      id_key: "beginning",
      label: "Beginning Proficiency",
      label_lines: ["Beginning", "Proficiency"],
      icon: :seed,
      description:
        "You’re beginning to learn how to apply this learning objective. Continue practicing and reviewing feedback to strengthen your proficiency."
    }
  end

  def display_for(proficiency) do
    %{
      level: :not_enough_information,
      source_value: proficiency,
      id_key: "not_enough",
      label: @default_label,
      label_lines: ["Not Enough", "Information"],
      icon: :empty_pot,
      description: "Complete a few more activities before we can estimate your proficiency."
    }
  end
end
