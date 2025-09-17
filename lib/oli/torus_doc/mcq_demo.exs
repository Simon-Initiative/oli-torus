# Demo script for TorusDoc MCQ Activity support
# Run with: mix run lib/oli/torus_doc/mcq_demo.exs

# Example 1: Standalone MCQ activity
mcq_yaml = """
type: "oli_multi_choice"
id: "physics_mcq_1"
title: "Uniform Acceleration — Concept Check"
objectives: [2423, 1345]
tags: [4534, 6789]
shuffle: true

stem_md: |
  Watch the short clip and answer the question.

  :::youtube { id="dQw4w9WgXcQ" start=42 title="Kinematics demo" }:::

  Which quantity remains **constant** during the motion?

  - You may assume negligible friction.
  - Recall: $a = \\frac{\\Delta v}{\\Delta t}$.

choices:
  - id: "A"
    score: 0
    body_md: |
      **Velocity** is constant.

      ![Flat line](./img/velocity-flat.png "Velocity vs. time (flat)?")
    feedback_md: |
      The slope of the velocity–time graph changes, so velocity is not constant.

  - id: "B"
    score: 5
    body_md: |
      **Acceleration** is constant.

      $$ a(t) = \\text{const} $$
    feedback_md: |
      Correct — uniform acceleration means $\\frac{\\Delta v}{\\Delta t}$ is constant.

  - id: "C"
    score: 0
    body_md: |
      **Position** is constant.
    feedback_md: |
      If position were constant, velocity would be zero throughout.

  - id: "D"
    score: 0
    body_md: |
      **Jerk** is constant.
    feedback_md: |
      There's no evidence of constant jerk in this clip.

incorrect_feedback_md: |
  Revisit the definition $a = \\Delta v / \\Delta t$ and compare frames 00:42–00:48.

hints:
  - body_md: |
      What does the slope of the velocity–time graph represent?
  - body_md: |
      If acceleration is constant, how does velocity change over time?
  - body_md: |
      If velocity is changing, can position be constant?

explanation_md: |
  The object is undergoing **uniform acceleration**. This means that the acceleration $a$ is constant, which implies that the velocity $v$ changes linearly over time. The position $x$ changes non-linearly, and jerk (the rate of change of acceleration) is not constant.

  - **Velocity** is not constant because the slope of the velocity–time graph changes.
  - **Position** is not constant because the object is moving.
  - **Jerk** is not constant because there is no indication of a steady change in acceleration.

  Therefore, the correct answer is that **acceleration** remains constant during the motion.
"""

# Parse and convert standalone MCQ
IO.puts("\\n=== Example 1: Standalone MCQ Activity ===\\n")
IO.puts("Input YAML:")
IO.puts(mcq_yaml)

case Oli.TorusDoc.ActivityConverter.from_yaml(mcq_yaml) do
  {:ok, json} ->
    IO.puts("\\nOutput JSON (pretty-printed):")
    IO.puts(Jason.encode!(json, pretty: true))

    IO.puts("\\n✅ Successfully converted standalone MCQ activity")
    IO.puts("   - Activity type: #{json["activityType"]}")
    IO.puts("   - Number of choices: #{length(json["choices"])}")

    IO.puts(
      "   - Has shuffle transformation: #{length(json["authoring"]["transformations"]) > 0}"
    )

    IO.puts("   - Number of hints: #{length(List.first(json["authoring"]["parts"])["hints"])}")

  {:error, reason} ->
    IO.puts("\\n❌ Error converting MCQ: #{reason}")
end

# Example 2: Page with embedded MCQ
page_with_mcq_yaml = """
type: "page"
id: "physics_quiz_page"
title: "Physics Quiz - Kinematics"
graded: true
blocks:
  - type: "prose"
    body_md: |
      # Kinematics Quiz

      This quiz tests your understanding of uniform acceleration.
      
      ## Instructions
      - Watch the video carefully
      - Consider the given assumptions
      - Select the best answer

  - type: "group"
    purpose: "learnbydoing"
    layout: "vertical"
    blocks:
      - type: "activity"
        id: "inline_mcq_1"
        activity_type: "oli_multi_choice"
        stem_md: |
          Based on the kinematic equations, if an object starts from rest and accelerates uniformly at $2 \\text{ m/s}^2$, what is its velocity after 5 seconds?
        shuffle: false
        choices:
          - id: "A"
            score: 0
            body_md: "$5 \\text{ m/s}$"
            feedback_md: "Remember: $v = v_0 + at$, and $v_0 = 0$"
          - id: "B"
            score: 1
            body_md: "$10 \\text{ m/s}$"
            feedback_md: "Correct! $v = 0 + 2 \\times 5 = 10 \\text{ m/s}$"
          - id: "C"
            score: 0
            body_md: "$25 \\text{ m/s}$"
            feedback_md: "This would be the distance traveled, not the velocity"
        hints:
          - body_md: "Use the equation $v = v_0 + at$"
          - body_md: "The initial velocity $v_0 = 0$ (starts from rest)"
        explanation_md: |
          Using the kinematic equation for velocity:
          
          $v = v_0 + at$
          
          Where:
          - $v_0 = 0$ (starts from rest)
          - $a = 2 \\text{ m/s}^2$
          - $t = 5 \\text{ s}$
          
          Therefore: $v = 0 + 2 \\times 5 = 10 \\text{ m/s}$

      - type: "activity"
        id: "ref_to_existing"
        activity_id: "physics_mcq_1"  # Reference to the standalone activity above

  - type: "prose"
    body_md: |
      ## Summary
      
      Remember the key kinematic equations:
      - $v = v_0 + at$
      - $x = x_0 + v_0 t + \\frac{1}{2}at^2$
      - $v^2 = v_0^2 + 2a(x - x_0)$
"""

# Parse and convert page with MCQ
IO.puts("\\n\\n=== Example 2: Page with Embedded MCQ ===\\n")
IO.puts("Input YAML (truncated):")
IO.puts(String.slice(page_with_mcq_yaml, 0..500) <> "...\\n")

case Oli.TorusDoc.PageConverter.from_yaml(page_with_mcq_yaml) do
  {:ok, json} ->
    IO.puts("\\nOutput JSON structure:")
    IO.puts("Page:")
    IO.puts("  - ID: #{json["id"]}")
    IO.puts("  - Title: #{json["title"]}")
    IO.puts("  - Graded: #{json["isGraded"]}")
    IO.puts("  - Number of blocks: #{length(json["content"]["model"])}")

    # Find activity references
    activity_refs =
      json["content"]["model"]
      |> Enum.flat_map(fn block ->
        case block["type"] do
          "group" ->
            block["children"]
            |> Enum.filter(&(&1["type"] == "activity-reference"))

          "activity-reference" ->
            [block]

          _ ->
            []
        end
      end)

    IO.puts("\\nActivity References Found:")

    Enum.each(activity_refs, fn ref ->
      IO.puts("  - Slug: #{ref["activitySlug"]}")

      if Map.has_key?(ref, "_inline_activity") do
        IO.puts("    Type: Inline")
        IO.puts("    Activity Type: #{ref["_inline_activity"]["activityType"]}")
      else
        IO.puts("    Type: Reference")
      end
    end)

    IO.puts("\\n✅ Successfully converted page with MCQ activities")

  {:error, reason} ->
    IO.puts("\\n❌ Error converting page: #{reason}")
end

# Example 3: Simple MCQ for testing
simple_mcq_yaml = """
type: "oli_multi_choice"
stem_md: "What is the capital of France?"
choices:
  - id: "A"
    body_md: "London"
    score: 0
    feedback_md: "London is the capital of the UK."
  - id: "B"
    body_md: "Paris"
    score: 1
    feedback_md: "Correct! Paris is the capital of France."
  - id: "C"
    body_md: "Berlin"
    score: 0
    feedback_md: "Berlin is the capital of Germany."
  - id: "D"
    body_md: "Madrid"
    score: 0
    feedback_md: "Madrid is the capital of Spain."
shuffle: true
incorrect_feedback_md: "Think about famous French landmarks like the Eiffel Tower."
hints:
  - body_md: "It's known as the City of Light."
  - body_md: "The Eiffel Tower is located there."
"""

IO.puts("\\n\\n=== Example 3: Simple MCQ ===\\n")

case Oli.TorusDoc.ActivityConverter.from_yaml(simple_mcq_yaml) do
  {:ok, json} ->
    IO.puts("✅ Successfully converted simple MCQ")

    IO.puts(
      "   - Question: #{String.slice(json["stem"]["content"] |> List.first() |> Map.get("children") |> List.first() |> Map.get("text"), 0..50)}..."
    )

    IO.puts("   - Choices: #{json["choices"] |> Enum.map(& &1["id"]) |> Enum.join(", ")}")

    IO.puts(
      "   - Correct choice(s): #{json["authoring"]["parts"] |> List.first() |> Map.get("responses") |> Enum.filter(&(&1["score"] > 0)) |> Enum.map(& &1["rule"]) |> Enum.join(", ")}"
    )

  {:error, reason} ->
    IO.puts("❌ Error: #{reason}")
end

IO.puts("\\n=== Demo Complete ===\\n")
