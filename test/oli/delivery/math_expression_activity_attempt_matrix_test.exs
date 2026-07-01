defmodule Oli.Delivery.MathExpressionActivityAttemptMatrixTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Activities
  alias Oli.Activities.Model
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Repo
  alias Oli.TorusDoc.ActivityConverter
  alias Oli.TorusDoc.ActivityParser

  setup do
    ensure_activity_registration("oli_short_answer", "Short Answer")
    ensure_activity_registration("oli_multi_input", "Multi Input")

    %{user: insert(:user), section: insert(:section)}
  end

  test "math expression activities evaluate through persisted activity attempts", %{
    user: user,
    section: section
  } do
    [
      single("single algebraic with domain",
        subtype: "algebraic",
        answer: "x^2 + 2*x",
        validation: variables(["x"], [domain("x", -5, 5, integer: true, except: [0])]),
        cases: [
          solves("x*(x + 2)", score: 1, feedback: "correct"),
          misses("x^2 + 3*x")
        ]
      ),
      single("single fraction with exact and equivalent targeted feedback",
        subtype: "fraction",
        responses: [
          correct("1/2", 2, subtype: "simplified_fraction", feedback: "simplified"),
          targeted("1/2", 1, subtype: "fraction", feedback: "equivalent"),
          incorrect()
        ],
        cases: [
          solves("1/2", score: 2, out_of: 2, feedback: "simplified"),
          solves("4/8", score: 1, out_of: 2, feedback: "equivalent"),
          misses("2/3", out_of: 2)
        ]
      ),
      single("single number with units and unit-targeted custom scoring",
        subtype: "number_with_units",
        unit_policy: convertible_units(["m/s", "km/hr"]),
        responses: [
          correct("10 m/s", 2, feedback: "correct"),
          targeted("10 m/s", 1.5, wrong_units: true, feedback: "wrong-units"),
          targeted("10 m/s", 1, missing_unit: true, feedback: "missing-unit"),
          incorrect()
        ],
        cases: [
          solves("10 m/s", score: 2, out_of: 2, feedback: "correct"),
          solves("10 cm/s", score: 1.5, out_of: 2, feedback: "wrong-units"),
          solves("10", score: 1, out_of: 2, feedback: "missing-unit"),
          misses("9 cm/s", out_of: 2)
        ]
      ),
      single("single number with units numeric tolerance",
        subtype: "number_with_units",
        unit_policy: convertible_units(["m/s", "km/hr"]),
        responses: [
          correct("10", 2,
            subtype: "number_with_units",
            tolerance: absolute_tolerance(0.25),
            operator: "equal",
            feedback: "unit-tolerance-absolute"
          ),
          incorrect()
        ],
        cases: [
          solves("36.72 km/hr", score: 2, out_of: 2, feedback: "unit-tolerance-absolute"),
          misses("37.08 km/hr", out_of: 2)
        ]
      ),
      single("single number with units numeric greater-than and unit targets",
        subtype: "number_with_units",
        unit_policy: convertible_units(["m/s"]),
        responses: [
          correct("10", 2,
            subtype: "number_with_units",
            operator: "greater_than",
            feedback: "unit-greater-than"
          ),
          targeted("10", 1.5,
            subtype: "number_with_units",
            operator: "greater_than",
            wrong_units: true,
            feedback: "unit-greater-than-wrong-units"
          ),
          targeted("10", 1,
            subtype: "number_with_units",
            operator: "greater_than",
            missing_unit: true,
            feedback: "unit-greater-than-missing-unit"
          ),
          incorrect()
        ],
        cases: [
          solves("11 m/s", score: 2, out_of: 2, feedback: "unit-greater-than"),
          solves("11 cm/s",
            score: 1.5,
            out_of: 2,
            feedback: "unit-greater-than-wrong-units"
          ),
          solves("11",
            score: 1,
            out_of: 2,
            feedback: "unit-greater-than-missing-unit"
          ),
          misses("9 cm/s", out_of: 2)
        ]
      ),
      single("single algebraic expression with units and unit-targeted custom scoring",
        subtype: "expression_with_units",
        answer: "x m/s",
        validation: variables(["x"], [domain("x", 1, 10)]),
        unit_policy: convertible_units(["m/s", "km/hr"]),
        responses: [
          correct("x m/s", 2, feedback: "correct"),
          targeted("x m/s", 1.5, wrong_units: true, feedback: "wrong-units"),
          targeted("x m/s", 1, missing_unit: true, feedback: "missing-unit"),
          incorrect()
        ],
        cases: [
          solves("x m/s", score: 2, out_of: 2, feedback: "correct"),
          solves("x cm/s", score: 1.5, out_of: 2, feedback: "wrong-units"),
          solves("x", score: 1, out_of: 2, feedback: "missing-unit"),
          misses("2*x cm/s", out_of: 2)
        ]
      ),
      single("single numeric tolerance options",
        subtype: "numeric",
        responses: [
          correct("10", 2,
            subtype: "numeric",
            tolerance: no_tolerance(),
            feedback: "single-tolerance-none"
          ),
          correct("20", 2,
            subtype: "numeric",
            tolerance: absolute_tolerance(0.5),
            feedback: "single-tolerance-absolute"
          ),
          correct("100", 2,
            subtype: "numeric",
            tolerance: relative_tolerance(0.1),
            feedback: "single-tolerance-relative"
          ),
          correct("1000", 2,
            subtype: "numeric",
            tolerance: absolute_or_relative_tolerance(0.5, 0.001),
            feedback: "single-tolerance-absolute-or-relative"
          ),
          incorrect()
        ],
        cases: [
          solves("10", score: 2, out_of: 2, feedback: "single-tolerance-none"),
          solves("20.4", score: 2, out_of: 2, feedback: "single-tolerance-absolute"),
          solves("109", score: 2, out_of: 2, feedback: "single-tolerance-relative"),
          solves("1000.8",
            score: 2,
            out_of: 2,
            feedback: "single-tolerance-absolute-or-relative"
          ),
          misses("10.1", out_of: 2)
        ]
      ),
      single("single exact forms and numeric modes",
        cases: [
          solves("3.14",
            subtype: "numeric",
            answer: "3.14",
            score: 1,
            feedback: "numeric"
          ),
          solves("2", subtype: "integer", answer: "2", score: 1, feedback: "integer"),
          solves("0.5", subtype: "decimal", answer: "0.5", score: 1, feedback: "decimal"),
          solves("2/4", subtype: "fraction", answer: "1/2", score: 1, feedback: "fraction"),
          solves("\\frac{1}{2}",
            subtype: "latex_direct",
            answer: "\\frac{1}{2}",
            score: 1,
            feedback: "latex"
          )
        ]
      ),
      multi("multi input math expression parts with unit-targeted custom scoring",
        inputs: [
          input("speed",
            subtype: "number_with_units",
            answer: "10 m/s",
            unit_policy: convertible_units(["m/s", "km/hr"]),
            responses: [
              correct("10 m/s", 2, subtype: "number_with_units", feedback: "speed"),
              targeted("10 m/s", 1.5,
                subtype: "number_with_units",
                wrong_units: true,
                feedback: "speed-wrong-units"
              ),
              targeted("10 m/s", 1,
                subtype: "number_with_units",
                missing_unit: true,
                feedback: "speed-missing-unit"
              ),
              incorrect()
            ]
          ),
          input("formula",
            subtype: "expression_with_units",
            answer: "x m/s",
            validation: variables(["x"], [domain("x", 1, 10)]),
            unit_policy: convertible_units(["m/s", "km/hr"]),
            responses: [
              correct("x m/s", 2, subtype: "expression_with_units", feedback: "formula"),
              targeted("x m/s", 1.5,
                subtype: "expression_with_units",
                wrong_units: true,
                feedback: "formula-wrong-units"
              ),
              targeted("x m/s", 1,
                subtype: "expression_with_units",
                missing_unit: true,
                feedback: "formula-missing-unit"
              ),
              incorrect()
            ]
          ),
          input("fraction",
            subtype: "fraction",
            answer: "1/2",
            responses: [
              correct("1/2", 2, subtype: "simplified_fraction", feedback: "fraction"),
              targeted("1/2", 1, subtype: "fraction", feedback: "fraction-equivalent"),
              incorrect()
            ]
          )
        ],
        cases: [
          solves(%{"speed" => "10 m/s", "formula" => "x m/s", "fraction" => "1/2"},
            score: 6,
            out_of: 6,
            parts: [
              part("speed", 2, "speed"),
              part("formula", 2, "formula"),
              part("fraction", 2, "fraction")
            ]
          ),
          solves(%{"speed" => "10 cm/s", "formula" => "x cm/s", "fraction" => "1/2"},
            score: 5,
            out_of: 6,
            parts: [
              part("speed", 1.5, "speed-wrong-units", 2),
              part("formula", 1.5, "formula-wrong-units", 2),
              part("fraction", 2, "fraction")
            ]
          ),
          solves(%{"speed" => "10", "formula" => "x", "fraction" => "1/2"},
            score: 4,
            out_of: 6,
            parts: [
              part("speed", 1, "speed-missing-unit", 2),
              part("formula", 1, "formula-missing-unit", 2),
              part("fraction", 2, "fraction")
            ]
          ),
          solves(%{"speed" => "10 m/s", "formula" => "x m/s", "fraction" => "4/8"},
            score: 5,
            out_of: 6,
            parts: [
              part("speed", 2, "speed"),
              part("formula", 2, "formula"),
              part("fraction", 1, "fraction-equivalent", 2)
            ]
          ),
          solves(%{"speed" => "10 m/s", "formula" => "x m/s", "fraction" => "2/3"},
            score: 4,
            out_of: 6,
            parts: [
              part("speed", 2, "speed"),
              part("formula", 2, "formula"),
              part("fraction", 0, "incorrect", 2)
            ]
          )
        ]
      ),
      multi("multi input numeric tolerance options",
        inputs: [
          input("tol_none",
            subtype: "numeric",
            answer: "10",
            tolerance: no_tolerance(),
            score: 2,
            feedback: "multi-tolerance-none"
          ),
          input("tol_absolute",
            subtype: "numeric",
            answer: "20",
            tolerance: absolute_tolerance(0.5),
            score: 2,
            feedback: "multi-tolerance-absolute"
          ),
          input("tol_relative",
            subtype: "numeric",
            answer: "100",
            tolerance: relative_tolerance(0.1),
            score: 2,
            feedback: "multi-tolerance-relative"
          ),
          input("tol_absolute_or_relative",
            subtype: "numeric",
            answer: "1000",
            tolerance: absolute_or_relative_tolerance(0.5, 0.001),
            score: 2,
            feedback: "multi-tolerance-absolute-or-relative"
          )
        ],
        cases: [
          solves(
            %{
              "tol_none" => "10",
              "tol_absolute" => "20.4",
              "tol_relative" => "109",
              "tol_absolute_or_relative" => "1000.8"
            },
            score: 8,
            out_of: 8,
            parts: [
              part("tol_none", 2, "multi-tolerance-none"),
              part("tol_absolute", 2, "multi-tolerance-absolute"),
              part("tol_relative", 2, "multi-tolerance-relative"),
              part("tol_absolute_or_relative", 2, "multi-tolerance-absolute-or-relative")
            ]
          ),
          solves(
            %{
              "tol_none" => "10.1",
              "tol_absolute" => "20.6",
              "tol_relative" => "112",
              "tol_absolute_or_relative" => "1001.1"
            },
            score: 0,
            out_of: 8,
            parts: [
              part("tol_none", 0, "incorrect", 2),
              part("tol_absolute", 0, "incorrect", 2),
              part("tol_relative", 0, "incorrect", 2),
              part("tol_absolute_or_relative", 0, "incorrect", 2)
            ]
          )
        ]
      )
    ]
    |> assert_activity_matrix(user, section)
  end

  defp assert_activity_matrix(activities, user, section) do
    Enum.each(activities, fn activity ->
      revision =
        activity
        |> activity_model()
        |> create_activity_revision(activity.slug)

      Enum.each(activity.cases, fn test_case ->
        setup = setup_activity_attempt(user, section, revision)

        results = submit(section, setup.activity_attempt, test_case.answer)

        assert_feedback_actions(results, test_case)
        assert_attempt_rows(setup.activity_attempt.attempt_guid, test_case)
      end)
    end)
  end

  defp single(title, opts) do
    cases = Keyword.fetch!(opts, :cases)
    default_subtype = Keyword.get(opts, :subtype, "algebraic")
    default_answer = Keyword.get(opts, :answer)

    %{
      title: title,
      slug: "oli_short_answer",
      type: :single,
      cases: Enum.map(cases, &inherit_case_defaults(&1, default_subtype, default_answer, opts)),
      opts: opts
    }
  end

  defp multi(title, opts) do
    %{
      title: title,
      slug: "oli_multi_input",
      type: :multi,
      cases: Keyword.fetch!(opts, :cases),
      opts: opts
    }
  end

  defp solves(answer, opts),
    do: Map.merge(%{answer: answer, score: 1, feedback: "correct"}, Map.new(opts))

  defp misses(answer, opts \\ []) do
    Map.merge(%{answer: answer, score: 0, out_of: 1, feedback: "incorrect"}, Map.new(opts))
  end

  defp part(id, score, feedback, out_of \\ nil),
    do: %{id: id, score: score, out_of: out_of || score, feedback: feedback}

  defp input(id, opts) do
    subtype = Keyword.fetch!(opts, :subtype)
    answer = Keyword.fetch!(opts, :answer)

    %{
      "id" => id,
      "input_type" => "math_expression",
      "math_expression" => math_expression(subtype, opts),
      "responses" =>
        Keyword.get(opts, :responses) ||
          [
            correct(answer, Keyword.get(opts, :score, 1),
              subtype: subtype,
              feedback: Keyword.get(opts, :feedback, id)
            ),
            incorrect()
          ]
    }
  end

  defp correct(answer, score, opts) do
    response(answer, score, Keyword.merge([correct: true], opts))
  end

  defp targeted(answer, score, opts), do: response(answer, score, opts)

  defp response(answer, score, opts) do
    %{
      "id" => "response-#{Keyword.get(opts, :feedback, score)}",
      "answer" => answer,
      "score" => score,
      "correct" => Keyword.get(opts, :correct, false),
      "feedback_id" => feedback_id(Keyword.get(opts, :feedback, "feedback")),
      "feedback_md" => Keyword.get(opts, :feedback, "feedback"),
      "math_expression" => math_expression(Keyword.get(opts, :subtype), opts)
    }
    |> maybe_put("match_wrong_units", Keyword.get(opts, :wrong_units))
    |> maybe_put("match_missing_unit", Keyword.get(opts, :missing_unit))
  end

  defp incorrect do
    %{
      "id" => "response-incorrect",
      "catch_all" => true,
      "score" => 0,
      "feedback_id" => feedback_id("incorrect"),
      "feedback_md" => "incorrect"
    }
  end

  defp inherit_case_defaults(test_case, default_subtype, default_answer, activity_opts) do
    test_case
    |> Map.put_new(:subtype, default_subtype)
    |> Map.put_new(:expected_answer, default_answer || test_case.answer)
    |> Map.put_new(:activity_opts, activity_opts)
    |> Map.put_new(:out_of, test_case.score)
  end

  defp activity_model(%{type: :single, title: title, cases: cases, opts: opts}) do
    case Keyword.get(opts, :responses) do
      nil ->
        content_for_case_activity(title, cases, opts)

      responses ->
        torusdoc_to_model(%{
          "type" => "oli_short_answer",
          "stem_md" => title,
          "input_type" => "math_expression",
          "math_expression" => math_expression(Keyword.fetch!(opts, :subtype), opts),
          "responses" => responses
        })
    end
  end

  defp activity_model(%{type: :multi, title: title, opts: opts}) do
    input_ids = Keyword.fetch!(opts, :inputs) |> Enum.map(& &1["id"])

    torusdoc_to_model(%{
      "type" => "oli_multi_input",
      "stem_md" => "#{title}: " <> Enum.map_join(input_ids, " ", &"{{#{&1}}}"),
      "inputs" => Keyword.fetch!(opts, :inputs)
    })
  end

  defp content_for_case_activity(title, cases, opts) do
    responses =
      cases
      |> Enum.map(fn test_case ->
        correct(test_case.expected_answer, test_case.score,
          subtype: test_case.subtype,
          feedback: test_case.feedback
        )
      end)
      |> Enum.reject(&(&1["score"] == 0))
      |> Kernel.++([incorrect()])

    first_case = hd(cases)

    torusdoc_to_model(%{
      "type" => "oli_short_answer",
      "stem_md" => title,
      "input_type" => "math_expression",
      "math_expression" => math_expression(first_case.subtype, opts),
      "responses" => responses
    })
  end

  defp torusdoc_to_model(content) do
    with {:ok, parsed} <- ActivityParser.parse_activity(content),
         {:ok, model} <- ActivityConverter.to_torus_json(parsed) do
      model
    else
      error -> flunk("Failed to build TorusDoc activity model: #{inspect(error)}")
    end
  end

  defp math_expression(nil, _opts), do: %{}

  defp math_expression(subtype, opts) do
    %{"subtype" => subtype}
    |> maybe_put("validation", Keyword.get(opts, :validation))
    |> maybe_put("unit_policy", Keyword.get(opts, :unit_policy))
    |> maybe_put("tolerance", Keyword.get(opts, :tolerance))
    |> maybe_put("operator", Keyword.get(opts, :operator))
    |> maybe_put("lower", Keyword.get(opts, :lower))
    |> maybe_put("upper", Keyword.get(opts, :upper))
    |> maybe_put("bounds", Keyword.get(opts, :bounds))
  end

  defp variables(names, domains) do
    %{"allowed_variables" => names}
    |> maybe_put("domains", domains)
  end

  defp no_tolerance, do: %{"type" => "none"}

  defp absolute_tolerance(value), do: %{"type" => "absolute", "value" => value}

  defp relative_tolerance(value), do: %{"type" => "relative", "value" => value}

  defp absolute_or_relative_tolerance(absolute, relative) do
    %{"type" => "absolute_or_relative", "absolute" => absolute, "relative" => relative}
  end

  defp domain(variable, lower, upper, opts \\ []) do
    %{"variable" => variable, "lower" => lower, "upper" => upper}
    |> maybe_put("integer_only", Keyword.get(opts, :integer))
    |> maybe_put("exclusions", Keyword.get(opts, :except))
  end

  defp convertible_units(units), do: %{"type" => "convertible_units", "units" => units}

  defp create_activity_revision(content, activity_type_slug) do
    activity_resource = insert(:resource)
    activity_type = Activities.get_registration_by_slug(activity_type_slug)

    insert(:revision,
      resource: activity_resource,
      resource_type_id: Oli.Resources.ResourceType.id_for_activity(),
      activity_type_id: activity_type.id,
      scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("total"),
      content: content
    )
  end

  defp setup_activity_attempt(user, section, activity_revision) do
    page_resource = insert(:resource)

    page_revision =
      insert(:revision,
        resource: page_resource,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => activity_revision.resource_id}
          ]
        },
        graded: false
      )

    insert(:section_resource,
      section: section,
      resource_id: page_resource.id,
      scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
      batch_scoring: false
    )

    resource_access =
      insert(:resource_access, user: user, section: section, resource: page_resource)

    resource_attempt =
      insert(:resource_attempt, resource_access: resource_access, revision: page_revision)

    activity_attempt =
      %Core.ActivityAttempt{
        attempt_guid: Ecto.UUID.generate(),
        attempt_number: 1,
        resource_id: activity_revision.resource_id,
        revision_id: activity_revision.id,
        resource_attempt_id: resource_attempt.id,
        lifecycle_state: :active,
        scoreable: true
      }
      |> Repo.insert!()
      |> Repo.preload([:revision, :resource_attempt])

    {:ok, %Model{parts: parts}} = Model.parse(activity_revision.content)

    part_attempts =
      Enum.map(parts, fn part ->
        insert(:part_attempt,
          activity_attempt: activity_attempt,
          part_id: part.id,
          lifecycle_state: :active
        )
      end)

    %{activity_attempt: activity_attempt, part_attempts: part_attempts}
  end

  defp submit(section, activity_attempt, answer) do
    part_attempts = Core.get_latest_part_attempts(activity_attempt.attempt_guid)

    part_inputs =
      Enum.map(part_attempts, fn part_attempt ->
        %{
          attempt_guid: part_attempt.attempt_guid,
          input: %StudentInput{input: answer_for_part(answer, part_attempt.part_id)}
        }
      end)

    assert {:ok, results} =
             Evaluate.evaluate_activity(
               section.slug,
               activity_attempt.attempt_guid,
               part_inputs,
               "math-expression-matrix"
             )

    results
  end

  defp answer_for_part(answer, _part_id) when is_binary(answer), do: answer
  defp answer_for_part(answer, part_id) when is_map(answer), do: Map.fetch!(answer, part_id)

  defp assert_feedback_actions(results, %{parts: expected_parts}) do
    actual =
      results
      |> Enum.map(&{&1.part_id, &1.score, &1.out_of, &1.feedback.id})
      |> Enum.sort()

    expected =
      expected_parts
      |> Enum.map(&{&1.id, &1.score * 1.0, &1.out_of * 1.0, feedback_id(&1.feedback)})
      |> Enum.sort()

    assert actual == expected
  end

  defp assert_feedback_actions([result], test_case) do
    assert result.score == test_case.score * 1.0, inspect(test_case)
    assert result.out_of == test_case.out_of * 1.0, inspect(test_case)
    assert result.feedback.id == feedback_id(test_case.feedback), inspect(test_case)
  end

  defp assert_attempt_rows(activity_attempt_guid, test_case) do
    updated_activity_attempt = Core.get_activity_attempt_by(attempt_guid: activity_attempt_guid)

    assert updated_activity_attempt.lifecycle_state == :evaluated
    assert updated_activity_attempt.score == test_case.score * 1.0
    assert updated_activity_attempt.out_of == test_case.out_of * 1.0

    part_attempts = Core.get_latest_part_attempts(activity_attempt_guid)

    Enum.each(part_attempts, fn part_attempt ->
      expected_part = expected_part_for(test_case, part_attempt.part_id)

      assert part_attempt.lifecycle_state == :evaluated
      assert part_attempt.score == expected_part.score * 1.0
      assert part_attempt.out_of == expected_part.out_of * 1.0

      assert part_attempt.response["input"] ==
               answer_for_part(test_case.answer, part_attempt.part_id)
    end)
  end

  defp expected_part_for(%{parts: parts}, part_id) do
    parts
    |> Map.new(&{&1.id, &1})
    |> Map.fetch!(part_id)
  end

  defp expected_part_for(test_case, _part_id) do
    %{score: test_case.score, out_of: test_case.out_of}
  end

  defp ensure_activity_registration(slug, title) do
    unless Activities.get_registration_by_slug(slug) do
      insert(:activity_registration, %{slug: slug, title: title})
    end
  end

  defp feedback_id(value), do: "feedback-#{value}"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, false), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
