defmodule OliWeb.Dev.MathPrototypeLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

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
      assert has_element?(view, "#algebraic-expected")
      assert has_element?(view, "#algebraic-candidate")
      assert has_element?(view, "#algebraic-sample-count")
      assert has_element?(view, "#algebraic-seed")
      assert has_element?(view, "#algebraic-max-attempts")
      assert has_element?(view, "#algebraic-allowed-variables")
      assert has_element?(view, "#algebraic-tolerance-type")
      assert has_element?(view, "#algebraic-include-special-points")
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
