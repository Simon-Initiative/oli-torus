defmodule Oli.Math.Gleam do
  @moduledoc false

  def parse(input), do: :torus_math.parse(input)

  def to_debug_string(parsed), do: :torus_math.to_debug_string(parsed)

  def parse_error_to_debug_string(error), do: :torus_math.parse_error_to_debug_string(error)

  def decode_equality_config(source), do: :torus_math.decode_equality_config(source)

  def encode_equality_config(spec), do: :torus_math.encode_equality_config(spec)

  def evaluate_equality(spec, submitted), do: :torus_math.evaluate_equality(spec, submitted)

  def decode_match_config(source), do: :torus_math.decode_match_config(source)

  def encode_match_config(config), do: :torus_math.encode_match_config(config)

  def evaluate_match(config, submitted), do: :torus_math.evaluate_match(config, submitted)

  def default_algebraic_equivalence_config do
    :torus_math.default_algebraic_equivalence_config()
  end

  def check_algebraic_equivalence(expected, candidate, config) do
    :torus_math.check_algebraic_equivalence(expected, candidate, config)
  end

  def algebraic_equivalence_result_to_debug_string(result) do
    :torus_math.algebraic_equivalence_result_to_debug_string(result)
  end

  def default_exact_form_config, do: :torus_math.default_exact_form_config()

  def check_exact_form(candidate, config), do: :torus_math.check_exact_form(candidate, config)

  def check_algebraic_equivalence_with_form(
        expected,
        candidate,
        equivalence_config,
        form_config
      ) do
    :torus_math.check_algebraic_equivalence_with_form(
      expected,
      candidate,
      equivalence_config,
      form_config
    )
  end

  def form_check_result_to_debug_string(result) do
    :torus_math.form_check_result_to_debug_string(result)
  end

  def form_aware_algebraic_result_to_debug_string(result) do
    :torus_math.form_aware_algebraic_result_to_debug_string(result)
  end

  def compare_quantities(expected, submitted, config, tolerance) do
    :torus_math.compare_quantities(expected, submitted, config, tolerance)
  end

  def unit_comparison_result_to_debug_string(result) do
    :torus_math.unit_comparison_result_to_debug_string(result)
  end
end
