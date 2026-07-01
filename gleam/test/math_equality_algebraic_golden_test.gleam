import gleeunit
import math/equality/algebraic_types
import math_equality_algebraic_golden_corpus as corpus
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn golden_corpus_covers_representative_algebraic_outcomes_test() {
  assert_golden_cases(corpus.cases())
}

pub fn golden_corpus_results_are_deterministic_test() {
  assert_deterministic_cases(corpus.cases())
}

fn assert_golden_cases(cases: List(corpus.GoldenCase)) {
  case cases {
    [] -> Nil
    [golden_case, ..rest] -> {
      assert_golden_case(golden_case)
      assert_golden_cases(rest)
    }
  }
}

fn assert_golden_case(golden_case: corpus.GoldenCase) {
  let corpus.GoldenCase(expected:, candidate:, config:, outcome:, ..) =
    golden_case
  let result =
    torus_math.check_algebraic_equivalence(expected, candidate, config)

  case outcome {
    corpus.ExpectEquivalent -> {
      let assert algebraic_types.AlgebraicEquivalenceResult(
        outcome: algebraic_types.Equivalent(_),
        summary: algebraic_types.EquivalenceSummary(
          outcome_category: algebraic_types.EquivalentOutcome,
          ..,
        ),
        ..,
      ) = result
      Nil
    }

    corpus.ExpectNotEquivalent -> {
      let assert algebraic_types.AlgebraicEquivalenceResult(
        outcome: algebraic_types.NotEquivalent(_),
        summary: algebraic_types.EquivalenceSummary(
          outcome_category: algebraic_types.NotEquivalentOutcome,
          ..,
        ),
        ..,
      ) = result
      Nil
    }

    corpus.ExpectValidationFailure -> {
      let assert algebraic_types.AlgebraicEquivalenceResult(
        outcome: algebraic_types.ValidationFailed(_),
        summary: algebraic_types.EquivalenceSummary(
          outcome_category: algebraic_types.ValidationFailureOutcome,
          ..,
        ),
        ..,
      ) = result
      Nil
    }

    corpus.ExpectCandidateUndefined -> {
      let assert algebraic_types.AlgebraicEquivalenceResult(
        outcome: algebraic_types.NotEquivalent(reason: algebraic_types.CandidateUndefined(
          _,
        )),
        summary: algebraic_types.EquivalenceSummary(
          outcome_category: algebraic_types.NotEquivalentOutcome,
          ..,
        ),
        ..,
      ) = result
      Nil
    }

    corpus.ExpectInsufficientSamples -> {
      let assert algebraic_types.AlgebraicEquivalenceResult(
        outcome: algebraic_types.InsufficientValidSamples(_),
        summary: algebraic_types.EquivalenceSummary(
          outcome_category: algebraic_types.InsufficientSamplesOutcome,
          ..,
        ),
        ..,
      ) = result
      Nil
    }
  }
}

fn assert_deterministic_cases(cases: List(corpus.GoldenCase)) {
  case cases {
    [] -> Nil
    [golden_case, ..rest] -> {
      let corpus.GoldenCase(expected:, candidate:, config:, ..) = golden_case
      let first =
        torus_math.check_algebraic_equivalence(expected, candidate, config)
      let second =
        torus_math.check_algebraic_equivalence(expected, candidate, config)

      assert first == second
      assert torus_math.algebraic_equivalence_result_to_debug_string(first)
        == torus_math.algebraic_equivalence_result_to_debug_string(second)
      assert_deterministic_cases(rest)
    }
  }
}
