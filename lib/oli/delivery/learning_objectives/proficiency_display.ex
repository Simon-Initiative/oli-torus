defmodule Oli.Delivery.LearningObjectives.ProficiencyDisplay do
  @moduledoc """
  Centralizes student-facing proficiency metadata for learning objectives.

  Maps persisted proficiency values to delivery labels, icons, and descriptions.
  Rendering details such as HTML, HEEx components, and Tailwind classes stay in
  web-facing callers.
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
