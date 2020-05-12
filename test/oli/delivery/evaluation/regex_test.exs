defmodule Oli.Delivery.Evaluation.RegexTest do

  use ExUnit.Case, async: true

  alias Oli.Delivery.Evaluation.Regex
  alias Oli.Activities.Model.{Part, Response, Feedback}
  alias Oli.Delivery.Attempts.{Result, StudentInput}

  test "evaluate a simple part" do

    part = %Part{
      id: 1,
      evaluation_strategy: :regex,
      scoring_strategy: "average",
      hints: [],
      responses: [
        %Response{id: 2, match: "A", score: 0, feedback: %Feedback{id: 3, content: []}},
        %Response{id: 3, match: "B", score: 1, feedback: %Feedback{id: 4, content: []}},
        %Response{id: 4, match: "C", score: 0, feedback: %Feedback{id: 5, content: []}},
        %Response{id: 5, match: "D", score: 0, feedback: %Feedback{id: 6, content: []}},
      ]
    }

    assert {:ok, {%Feedback{id: 3, content: []}, %Result{score: 0, out_of: 1}}} == Regex.evaluate(part, %StudentInput{input: "A"})
    assert {:ok, {%Feedback{id: 4, content: []}, %Result{score: 1, out_of: 1}}} == Regex.evaluate(part, %StudentInput{input: "B"})
    assert {:ok, {%Feedback{id: 5, content: []}, %Result{score: 0, out_of: 1}}} == Regex.evaluate(part, %StudentInput{input: "C"})
    assert {:ok, {%Feedback{id: 6, content: []}, %Result{score: 0, out_of: 1}}} == Regex.evaluate(part, %StudentInput{input: "D"})

  end

  test "evaluate a part with * and range of scores" do

    part = %Part{
      id: 1,
      evaluation_strategy: :regex,
      scoring_strategy: "average",
      hints: [],
      responses: [
        %Response{id: 2, match: "A", score: 3.4, feedback: %Feedback{id: 3, content: []}},
        %Response{id: 3, match: "B", score: 1, feedback: %Feedback{id: 4, content: []}},
        %Response{id: 4, match: "C", score: 7, feedback: %Feedback{id: 5, content: []}},
        %Response{id: 5, match: "*", score: 0, feedback: %Feedback{id: 6, content: []}},
      ]
    }

    assert {:ok, {%Feedback{id: 3, content: []}, %Result{score: 3.4, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "A"})
    assert {:ok, {%Feedback{id: 4, content: []}, %Result{score: 1, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "B"})
    assert {:ok, {%Feedback{id: 5, content: []}, %Result{score: 7, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "C"})
    assert {:ok, {%Feedback{id: 6, content: []}, %Result{score: 0, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "D"})

  end

  test "evaluate a part with * being somewhat correct" do

    part = %Part{
      id: 1,
      evaluation_strategy: :regex,
      scoring_strategy: "average",
      hints: [],
      responses: [
        %Response{id: 2, match: "A", score: 7, feedback: %Feedback{id: 3, content: []}},
        %Response{id: 3, match: "B", score: 1, feedback: %Feedback{id: 4, content: []}},
        %Response{id: 4, match: "C", score: 3, feedback: %Feedback{id: 5, content: []}},
        %Response{id: 5, match: "*", score: 2, feedback: %Feedback{id: 6, content: []}},
      ]
    }

    assert {:ok, {%Feedback{id: 3, content: []}, %Result{score: 7, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "A"})
    assert {:ok, {%Feedback{id: 6, content: []}, %Result{score: 2, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "B"})
    assert {:ok, {%Feedback{id: 5, content: []}, %Result{score: 3, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "C"})
    assert {:ok, {%Feedback{id: 6, content: []}, %Result{score: 2, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "D"})

  end

  test "evaluate a part with * being the most correct" do

    part = %Part{
      id: 1,
      evaluation_strategy: :regex,
      scoring_strategy: "average",
      hints: [],
      responses: [
        %Response{id: 2, match: "A", score: 3.4, feedback: %Feedback{id: 3, content: []}},
        %Response{id: 3, match: "B", score: 1, feedback: %Feedback{id: 4, content: []}},
        %Response{id: 4, match: "C", score: 3, feedback: %Feedback{id: 5, content: []}},
        %Response{id: 5, match: "*", score: 7, feedback: %Feedback{id: 6, content: []}},
      ]
    }

    assert {:ok, {%Feedback{id: 6, content: []}, %Result{score: 7, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "A"})
    assert {:ok, {%Feedback{id: 6, content: []}, %Result{score: 7, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "B"})
    assert {:ok, {%Feedback{id: 6, content: []}, %Result{score: 7, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "C"})
    assert {:ok, {%Feedback{id: 6, content: []}, %Result{score: 7, out_of: 7}}} == Regex.evaluate(part, %StudentInput{input: "D"})

  end


end
