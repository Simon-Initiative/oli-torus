defmodule Oli.Delivery.Evaluation.RuleEvalTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Evaluation.Rule
  alias Oli.Delivery.Evaluation.EvaluationContext

  defp eval(rule, input) do
    context = %EvaluationContext{
      resource_attempt_number: 1,
      activity_attempt_number: 1,
      part_attempt_number: 1,
      part_attempt_guid: "1",
      activity_attempt_guid: "1",
      page_id: 1,
      input: input
    }

    {:ok, tree} = Rule.parse(rule)

    case Rule.evaluate(tree, context) do
      {:ok, result} -> result
      {:error, e} -> {:error, e}
    end
  end

  test "evaluating negative decimal submissions against decimal value" do
    refute eval("input = {0.0200}", "-0.02")
  end

  test "evaluating integers" do
    assert eval("attemptNumber = {1} && input = {3}", "3")
    assert eval("attemptNumber = {1} && input_ref_ehdgwe = {3}", Poison.encode!(%{"ehdgwe" => 3}))
    refute eval("attemptNumber = {1} && input = {3}", "4")
    refute eval("attemptNumber = {1} && input = {3}", "33")
    refute eval("attemptNumber = {1} && input = {3}", "3.3")
    assert eval("attemptNumber = {1} && input > {2}", "3")
    assert eval("attemptNumber = {1} && input < {4}", "3")
    refute eval("attemptNumber = {1} && input > {3}", "3")
    refute eval("attemptNumber = {1} && input < {3}", "3")
  end

  test "evaluating floats" do
    assert eval("attemptNumber = {1} && input = {0.1}", "0.1")
    refute eval("attemptNumber = {1} && input = {0.1}", "0.2")
    # handles odd forms without digits on both sides of decimal
    assert eval("attemptNumber = {1} && input = {0.1}", ".1")
    refute eval("attemptNumber = {1} && input = {0.1}", ".2")
    assert eval("attemptNumber = {1} && input = {-0.1}", "-.1")
    refute eval("attemptNumber = {1} && input = {-0.1}", "-.2")
    assert eval("attemptNumber = {1} && input = {1.0}", "1.")
    refute eval("attemptNumber = {1} && input = {1.0}", "+2.")
    assert eval("attemptNumber = {1} && input = {-1.0}", "-1.")
    assert eval("attemptNumber = {1} && input = {3.1}", "3.1")
    refute eval("attemptNumber = {1} && input = {3.1}", "3.2")
    refute eval("attemptNumber = {1} && input = {3.1}", "4")
    refute eval("attemptNumber = {1} && input = {3.1}", "31")
    assert eval("attemptNumber = {1} && input > {2}", "3.2")
    assert eval("attemptNumber = {1} && input < {4}", "3.1")
    refute eval("attemptNumber = {1} && input > {3}", "3.0")
    refute eval("attemptNumber = {1} && input < {3}", "3.0")
    assert eval("attemptNumber = {1} && input < {3}", ".2")
  end

  test "evaluating ranges" do
    # scientific notation inside the range, evaluates to true
    assert eval("attemptNumber = {1} && input = {[4e-5,3e-3]}", "3e-4") == true

    assert eval("attemptNumber = {1} && input = {[3.0e+5,4.0e+5]}", "3.5e5") == true
    assert eval("attemptNumber = {1} && input = {[3.0e5,4.0e5]}", "3.5e5") == true

    # test bug parsing scientific notation w/positive exponent and no decimal point
    assert eval("attemptNumber = {1} && input = {[3e+5,4e+5]}", "3.5e5") == true
    assert eval("attemptNumber = {1} && input = {[3.0e5,5.0e5]}", "4e5") == true
    assert eval("attemptNumber = {1} && input = {[3e5,5e5]}", "4e6") == false

    # scientific notation using capital E
    assert eval("attemptNumber = {1} && input = {[4E-5,3E-3]}", "3E-4") == true

    assert eval("attemptNumber = {1} && input = {[3.0E+5,4.0e+5]}", "3.5E5") == true
    assert eval("attemptNumber = {1} && input = {[3.0e5,4.0E5]}", "3.5e5") == true

    # float inside the range, evaluates to true
    assert eval("attemptNumber = {1} && input = {(3,4)}", "3.1") == true
    assert eval("attemptNumber = {1} && input = {(3.0,4)}", "3.1") == true
    assert eval("attemptNumber = {1} && input = {(3,4.0)}", "3.1") == true
    assert eval("attemptNumber = {1} && input = {(3.0,4.0)}", "3.1") == true

    # outside the range, evaluates to false
    assert eval("attemptNumber = {1} && input = {(3,4)}", "2.0") == false

    # same value as exclusive lower boundary, evaluates to false
    assert eval("attemptNumber = {1} && input = {(3,4)}", "3") == false
    assert eval("attemptNumber = {1} && input = {(3,4)}", "3.0") == false

    # same value as exclusive upper boundary, evaluates to false
    assert eval("attemptNumber = {1} && input = {(3,4)}", "4") == false
    assert eval("attemptNumber = {1} && input = {(3,4)}", "4.0") == false

    # same value as inclusive lower boundary, evaluates to true
    assert eval("attemptNumber = {1} && input = {[3,4]}", "3") == true
    assert eval("attemptNumber = {1} && input = {[3,4]}", "3.0") == true
    assert eval("attemptNumber = {1} && input = {[3.0,4.0]}", "3") == true

    # same value as inclusive upper boundary, evaluates to true
    assert eval("attemptNumber = {1} && input = {[3,4]}", "4") == true
    assert eval("attemptNumber = {1} && input = {[3,4]}", "4.0") == true
    assert eval("attemptNumber = {1} && input = {[3.0,4.0]}", "4") == true

    assert eval("attemptNumber = {1} && input = {(-4.66e-19,-4.5e-19)}", "-4.6e-19") == true

    # gracefully handles space in between range
    assert eval("attemptNumber = {1} && input = {[3, 5]}", "4") == true

    # handles negative numbers in range
    assert eval("attemptNumber = {1} && input = {[-3, 5]}", "0") == true
    assert eval("attemptNumber = {1} && input = {[-3, 5]}", "-3.1") == false
    assert eval("attemptNumber = {1} && input = {(-3, 5)}", "1") == true
    assert eval("attemptNumber = {1} && input = {[-3.75, 5.1111]}", "1") == true
    assert eval("attemptNumber = {1} && input = {(-3.75, 5.1111)}", "1.002") == true
    assert eval("attemptNumber = {1} && input = {[3.75, 5]}", "-1.002") == false

    # handles range with precision
    assert eval("attemptNumber = {1} && input = {[-5, 5]#4}", "1.002") == true
    assert eval("attemptNumber = {1} && input = {(100, 101)#5}", "100.20") == true
    assert eval("attemptNumber = {1} && input = {(100, 101)#3}", "100.1") == false
    # significant figures of 0 maybe problematic
    assert eval("attemptNumber = {1} && input = {(-1, 1)#1}", "0") == true
    assert eval("attemptNumber = {1} && input = {(-1, 1)#1}", "0.0") == false
    assert eval("attemptNumber = {1} && input = {(-1, 1)#1}", "0.5") == true
    assert eval("attemptNumber = {1} && input = {(-1, 1)#1}", "0.50") == false

    # handle ranges in wrong order
    assert eval("attemptNumber = {1} && input = {[3e-3, 4e-5]}", "3e-4") == true
    assert eval("attemptNumber = {1} && input = {(4, 3.0)}", "3.1") == true
    assert eval("attemptNumber = {1} && input = {(4, 3)}", "2.0") == false
    assert eval("attemptNumber = {1} && input = {[4,3]}", "3") == true
    assert eval("attemptNumber = {1} && input = {[5, -3]}", "0") == true
    assert eval("attemptNumber = {1} && input = {[5, -3.0]}", "-3.1") == false
  end

  test "evaluating like" do
    assert eval("input like {cat}", "cat")
    refute eval("input like {cat}", "caaat")
    refute eval("input like {cat}", "ct")
    assert eval("input like {c.*?t}", "construct")
    refute eval("input like {c.*?t}", "apple")
  end

  test "evaluating numeric groupings" do
    assert eval("input = {1} || input > {1}", "1.5")
    assert eval("input = {1} || input > {1}", "1")
    refute eval("input = {1} || input > {1}", "0.1")
    refute eval("input = {11} || input > {11}", "1")

    assert eval("input = {1} || input < {1}", "0")
    assert eval("input = {1} || input < {1}", "1")
    refute eval("input = {1} || input < {1}", "1.5")
    refute eval("input = {1} || input < {1}", "1.1")
  end

  test "evaluating string groupings" do
    assert eval("attemptNumber = {1} && (input like {cat} || input like {dog})", "cat")
    assert eval("attemptNumber = {1} && (input like {cat} || input like {dog})", "dog")
  end

  test "evaluating negation" do
    assert eval("!(input like {cat})", "dog")
    assert !eval("!(input like {cat})", "cat")
  end

  test "evaluating complex groupings" do
    assert eval("input like {1} && (input like {2} && (!(input like {3})))", "1 2")
    assert eval("!(input like {1} && (input like {2} && (!(input like {3}))))", "1 3")
    assert eval("!(input like {1} && (input like {2} && (!(input like {3}))))", "1 2 3")
    assert eval("(!(input like {1})) && (input like {2})", "2")
  end

  test "evaluating input length" do
    assert eval("length(input) = {1}", "A")
    assert eval("length(input) < {10}", "Apple")
    assert eval("length(input) > {2}", "Apple")
  end

  test "evaluating string contains" do
    assert eval("input contains {cat}", "the cat in the hat")
    assert eval("input contains {cat}", "the CaT in the hat")
    assert eval("input contains {CaT}", "the cat in the hat")
    refute eval("input contains {cat}", "the bat in the hat")

    assert eval("!(input contains {cat})", "the bat in the hat")
    refute eval("!(input contains {cat})", "the cat in the hat")
  end

  test "evaluating string with normalization" do
    assert eval("input equals {my cat}", "my     cat   ")
  end

  test "evaluating string equals" do
    assert eval("input equals {cat}", "cat")
    refute eval("input equals {Cat}", "cat")
    refute eval("input equals {cat}", "Cat")

    assert eval("input equals {the cat in the hat}", "the cat in the hat")
    assert eval("input equals {the CaT in the HAT}", "the CaT in the HAT")
    refute eval("input equals {the cat in the HAT}", "the CaT in the HAT")
    refute eval("input equals { the cat in the hat}", "the cat in the hat")

    assert eval("!(input equals {cat})", "the cat in the hat")
    refute eval("!(input equals {the cat in the hat})", "the cat in the hat")
  end

  test "evaluating string iequals (case-insensitive)" do
    assert eval("input iequals {cat}", "cat")
    assert eval("input iequals {Cat}", "cat")
    assert eval("input iequals {cat}", "Cat")

    assert eval("input iequals {the cat in the hat}", "the CaT in the HAT")
    refute eval("input iequals {cat}", "the CaT in the HAT")
    refute eval("input iequals {CaT}", "the CaT in the HAT")

    assert eval("input iequals {the cat in the HAT}", "the CaT in the HAT")
    refute eval("input iequals { the cat in the hat}", "the cat in the hat")

    assert eval("!(input iequals {cat})", "the cat in the hat")
    refute eval("!(input iequals {the cat in the hat})", "the cat in the hat")
    refute eval("!(input iequals {the CAT in the hat})", "the cat in the HAT")
  end

  test "evaluating strings with a numeric operator results in error" do
    {:error, _} = eval("input < {3}", "*50")
    {:error, _} = eval("input < {3}", "cat")
    {:error, _} = eval("input = {apple}", "apple")
  end

  test "evaluating float and integer precision" do
    # precision specified, should evaluate matching precision to true
    assert eval("attemptNumber = {1} && input = {3.1#2}", "3.1")
    assert eval("attemptNumber = {1} && input = {0.36#2}", "0.36")

    # no precision specified, should evaluate extra precision to true
    assert eval("attemptNumber = {1} && input = {3.1}", "3.10")

    # precision specified, should evaluate extra precision to false
    refute eval("attemptNumber = {1} && input = {3.1#2}", "3.10")
    refute eval("attemptNumber = {1} && input = {0.036#2}", "3.60e-2")

    assert eval("attemptNumber = {1} && input = {0.001#1}", "0.001")
    assert eval("attemptNumber = {1} && input = {3.100#4}", "3.100")

    # significant figures: trailing zeros in decimal significant
    assert eval("attemptNumber = {1} && input = {0.0360#3}", "0.0360")
    # significant figures: e notation
    assert eval("attemptNumber = {1} && input = {0.0360#3}", "3.60E-2")
    refute eval("attemptNumber = {1} && input = {0.0360#3}", "3.6e-2")
    assert eval("attemptNumber = {1} && input = {0.360#3}", "360e-3")

    # significant figures in integers: trailing zeros not significant
    assert eval("attemptNumber = {1} && input = {3400#2}", "3400")
    refute eval("attemptNumber = {1} && input = {3400#2}", "3.400e3")
    refute eval("attemptNumber = {1} && input = {3400#4}", "3400")
    assert eval("attemptNumber = {1} && input = {3400#4}", "3.400e3")

    # eval returns false, although the precision is correct the value is wrong
    refute eval("attemptNumber = {1} && input = {3.268#2}", "3.2")
    refute eval("attemptNumber = {1} && input = {3.268#2}", "3.26")

    # eval returns false, although the value is correct, precision is wrong
    refute eval("attemptNumber = {1} && input = {3.268#2}", "3.268")

    # rule eval doesn't do any rounding, so these will return false
    refute eval("attemptNumber = {1} && input = {3.5#1}", "4")
    refute eval("attemptNumber = {1} && input = {3.25#2}", "3.3")

    # even though the value specified is more precise, the value and expected precision match
    assert eval("attemptNumber = {1} && input = {3.100#2}", "3.1")

    # even though the value specified is less precise, the value and expected precision match
    assert eval("attemptNumber = {1} && input = {2#2}", "2.0")

    # input is greater than, but precision is wrong
    refute eval("attemptNumber = {1} && input > {2#3}", "3.2")

    # input is less than, but precision is wrong
    refute eval("attemptNumber = {1} && input < {4#1}", "3.8")

    # precision is correct, but input is equal to
    refute eval("attemptNumber = {1} && input < {3#4}", "3.000")

    assert eval("attemptNumber = {1} && input < {4#2}", "3.1")
    assert eval("attemptNumber = {1} && input < {4#1}", "3")
    assert eval("attemptNumber = {1} && input > {3#2}", "3.1")
    assert eval("attemptNumber = {1} && input > {3#1}", "4")

    # Ensures small scientific notation floats are not incorrectly considered equal
    refute eval("input = {2.2e-10}", "2.2e-11")
  end
end
