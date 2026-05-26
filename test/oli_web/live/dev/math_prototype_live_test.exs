defmodule OliWeb.Dev.MathPrototypeLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  # @ac "AC-009" Decimal precision controls exercise exactly, at least, and at most rules.
  # @ac "AC-010" Simplified-fraction form failure is shown after semantic pass.
  # @ac "AC-011" Semantic failure stays primary before form feedback.
  # @ac "AC-012" Malformed candidates and invalid config render structured errors.
  # @ac "AC-015" Phase 7 runs the full Gleam suite that includes numeric compatibility tests.
  # @ac "AC-016" Exact-form UI is scoped to the developer Math Prototype LiveView.
  # @ac "AC-017" The prototype renders transient diagnostics without adding logs or telemetry.
  # @ac "AC-018" Phase 7 runs both required Gleam targets.
  describe "parser prototype" do
    test "renders the existing parser playground", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dev/math_prototype")

      assert html =~ "Math Prototype"
      assert has_element?(view, "#math-expression")

      html = view |> element("button", "Parse on server") |> render_click()

      assert html =~ "Server result"
      assert html =~ "Status:"
    end
  end

  describe "algebraic equivalence prototype" do
    test "renders form controls, domain rows, and proof-warning copy", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dev/math_prototype")

      assert has_element?(view, "#algebraic-equivalence-panel")
      assert html =~ ~s(id="algebraic-form")
      assert html =~ "novalidate"
      assert has_element?(view, "#algebraic-expected")
      assert has_element?(view, "#algebraic-candidate")
      assert has_element?(view, "#algebraic-sample-count")
      assert has_element?(view, "#algebraic-seed")
      assert has_element?(view, "#algebraic-max-attempts")
      assert has_element?(view, "#algebraic-allowed-variables")
      assert has_element?(view, "#algebraic-tolerance-type")
      assert has_element?(view, "#algebraic-include-special-points")
      assert has_element?(view, "#unit-equivalence-controls")
      assert has_element?(view, "#algebraic-unit-mode")
      assert has_element?(view, "#algebraic-accepted-units")
      assert has_element?(view, "#algebraic-conversion-policy")
      assert has_element?(view, "#algebraic-final-unit-policy")
      assert has_element?(view, "#exact-form-controls")
      assert has_element?(view, "#algebraic-form-constraint")
      assert has_element?(view, "#algebraic-decimal-precision-rule")
      assert has_element?(view, "#algebraic-decimal-precision-count")
      assert has_element?(view, "#algebraic-domain-row-0")
      assert has_element?(view, "#domain-0-lower-bound")
      assert has_element?(view, "#domain-0-upper-bound")
      assert html =~ "Deterministic sampling is not symbolic proof"
    end

    test "adds and removes per-variable domain rows", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html = view |> element("button", "Add domain row") |> render_click()
      assert html =~ ~s(id="algebraic-domain-row-1")

      html = view |> element("#algebraic-domain-row-1 button", "Remove") |> render_click()
      refute html =~ ~s(id="algebraic-domain-row-1")
      assert html =~ ~s(id="algebraic-domain-row-0")
    end

    test "checks equivalent expressions and renders full sample details", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "2(x+3)",
              "candidate" => "2x+6"
            })
        )
        |> render_submit()

      assert html =~ "Equivalent"
      assert html =~ "Last equivalence check"
      assert html =~ "Checks run: 1"
      assert html =~ "Accepted sample comparisons"
      assert html =~ "Rejected sample summaries"
      assert html =~ "Stable debug text"
      assert html =~ "EquivalenceSummary"
      assert html =~ "SampleComparison"
      refute html =~ ~s(id="exact-form-result")
    end

    test "checks a near miss as not equivalent with first failure details", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "2(x+3)",
              "candidate" => "2x+7"
            })
        )
        |> render_submit()

      assert html =~ "Not equivalent"
      assert html =~ "First failure"
      assert html =~ "ValueMismatch"
    end

    test "shows parse error diagnostics", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "",
              "candidate" => "x"
            })
        )
        |> render_submit()

      assert html =~ "Parse error"
      assert html =~ "ExpectedParseFailed"
      assert html =~ "Stable debug text"
    end

    test "applies per-variable domain rows to the check", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "x",
              "candidate" => "x",
              "allowed_variables" => "x",
              "sample_count" => "3",
              "domains" => %{
                "0" => %{
                  "name" => "x",
                  "lower" => "1",
                  "lower_bound" => "inclusive",
                  "upper" => "3",
                  "upper_bound" => "inclusive",
                  "integer_only" => "true",
                  "exclusions" => "",
                  "preferred_values" => "1 2"
                }
              }
            })
        )
        |> render_submit()

      assert html =~ "Equivalent"
      assert html =~ "Variables:"
      assert html =~ "x"
    end

    test "shows form-level config errors without running a check", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "sample_count" => "NaN"
            })
        )
        |> render_submit()

      assert html =~ "Check failed"
      assert html =~ "Checks run: 1"
      assert html =~ "sample_count"
      assert html =~ "must be an integer"
      assert html =~ "No equivalence check has been run yet."
    end

    test "reports semantic pass with simplified fraction form failure", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "1/2",
              "candidate" => "2/4",
              "form_constraint" => "simplified_fraction"
            })
        )
        |> render_submit()

      assert html =~ "Form failed"
      assert html =~ "Semantic category:"
      assert html =~ "Semantic outcome:"
      assert html =~ "Passed"
      assert html =~ "Form outcome:"
      assert html =~ "Failed"
      assert html =~ "First failure:"
      assert html =~ "Exact-form debug text"
      assert html =~ "SemanticsPassedFormFailed"
      assert html =~ "UnsimplifiedFraction"
    end

    test "reports semantic pass with plain fraction form satisfaction", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      change_html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "1/2",
              "candidate" => "4/8",
              "form_constraint" => "fraction"
            })
        )
        |> render_change()

      assert change_html =~ ~s(value="fraction" selected)

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "1/2",
              "candidate" => "4/8",
              "form_constraint" => "fraction"
            })
        )
        |> render_submit()

      assert html =~ "Equivalent"
      assert html =~ "Semantic outcome:"
      assert html =~ "Passed"
      assert html =~ "Form outcome:"
      assert html =~ "Satisfied"
      assert html =~ "SemanticsPassedFormSatisfied"
      assert html =~ "ObservedFraction"
    end

    test "preserves semantic failure as primary before form feedback", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "4/5",
              "candidate" => "8/11",
              "form_constraint" => "simplified_fraction"
            })
        )
        |> render_submit()

      assert html =~ "Not equivalent"
      assert html =~ "Semantic outcome:"
      assert html =~ "Failed"
      assert html =~ "Form outcome:"
      assert html =~ "Not checked"
      assert html =~ "SemanticsFailed"
      refute html =~ "WrongForm"
    end

    test "shows malformed candidate semantic errors without form failures", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "4/5",
              "candidate" => "",
              "form_constraint" => "simplified_fraction"
            })
        )
        |> render_submit()

      assert html =~ "Parse error"
      assert html =~ "Semantic outcome:"
      assert html =~ "Failed"
      assert html =~ "Form outcome:"
      assert html =~ "Not checked"
      assert html =~ "CandidateParseFailed"
    end

    test "shows invalid exact-form config errors without crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "form_constraint" => "decimal",
              "decimal_precision_rule" => "exactly",
              "decimal_precision_count" => "-1"
            })
        )
        |> render_submit()

      assert html =~ "Check failed"
      assert html =~ "decimal_precision_count"
      assert html =~ "must be a non-negative integer"
      assert html =~ "No equivalence check has been run yet."
    end

    test "validates decimal precision rules", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      exactly_html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "0.8",
              "candidate" => "0.8",
              "form_constraint" => "decimal",
              "decimal_precision_rule" => "exactly",
              "decimal_precision_count" => "2"
            })
        )
        |> render_submit()

      assert exactly_html =~ "DecimalPrecisionMismatch"
      assert exactly_html =~ "Form failed"
      assert exactly_html =~ "Form outcome:"
      assert exactly_html =~ "Failed"

      at_least_html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "0.8",
              "candidate" => "0.80",
              "form_constraint" => "decimal",
              "decimal_precision_rule" => "at_least",
              "decimal_precision_count" => "2"
            })
        )
        |> render_submit()

      assert at_least_html =~ "SemanticsPassedFormSatisfied"
      assert at_least_html =~ "Form outcome:"
      assert at_least_html =~ "Satisfied"

      at_most_html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "0.8",
              "candidate" => "0.8",
              "form_constraint" => "decimal",
              "decimal_precision_rule" => "at_most",
              "decimal_precision_count" => "2"
            })
        )
        |> render_submit()

      assert at_most_html =~ "SemanticsPassedFormSatisfied"
      assert at_most_html =~ "Form outcome:"
      assert at_most_html =~ "Satisfied"
    end

    test "checks equivalent unit quantities through the equivalency panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "9.8 m/s^2",
              "candidate" => "980 cm/s^2",
              "unit_mode" => "require",
              "accepted_units" => "m/s^2, cm/s^2"
            })
        )
        |> render_submit()

      assert html =~ "Equivalent"
      assert html =~ "Last equivalence check"
      assert html =~ "Category:"
      assert html =~ ":correct"
      assert html =~ "UnitComparisonResult"
      assert html =~ "ComparisonResult"
    end

    test "reports incompatible units before numeric mismatch", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "9.8 m/s^2",
              "candidate" => "9.8 m/s",
              "unit_mode" => "require",
              "accepted_units" => "m/s^2, m/s"
            })
        )
        |> render_submit()

      assert html =~ "Incompatible unit"
      assert html =~ ":incompatible_unit"
      assert html =~ "IncompatibleUnit"
    end

    test "reports strict final-unit rejection for convertible unit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dev/math_prototype")

      html =
        view
        |> form("#algebraic-form",
          algebraic:
            algebraic_params(%{
              "expected" => "9.8 m/s^2",
              "candidate" => "980 cm/s^2",
              "unit_mode" => "require",
              "accepted_units" => "m/s^2",
              "final_unit_policy" => "strict"
            })
        )
        |> render_submit()

      assert html =~ "Unit not accepted"
      assert html =~ ":unit_not_accepted"
      assert html =~ "UnitNotAccepted"
    end
  end

  defp algebraic_params(overrides) do
    Map.merge(
      %{
        "expected" => "2(x+3)",
        "candidate" => "2x+6",
        "allowed_variables" => "",
        "sample_count" => "8",
        "seed" => "42",
        "max_attempts" => "64",
        "include_special_points" => "true",
        "tolerance_type" => "default",
        "abs_tolerance" => "0.0001",
        "rel_tolerance" => "0.0001",
        "epsilon" => "0.000000000001",
        "unit_mode" => "off",
        "accepted_units" => "m/s^2, cm/s^2",
        "conversion_policy" => "allow",
        "final_unit_policy" => "any",
        "form_constraint" => "none",
        "decimal_precision_rule" => "any",
        "decimal_precision_count" => "2",
        "domains" => %{
          "0" => %{
            "name" => "",
            "lower" => "",
            "lower_bound" => "inclusive",
            "upper" => "",
            "upper_bound" => "inclusive",
            "integer_only" => "false",
            "exclusions" => "",
            "preferred_values" => ""
          }
        }
      },
      overrides
    )
  end
end
