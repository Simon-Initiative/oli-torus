defmodule Oli.Rendering.Content.MathMLSanitizerTest do
  use ExUnit.Case, async: true
  alias Oli.Rendering.Content.MathMLSanitizer
  alias HtmlSanitizeEx.Scrubber

  describe "mathml content sanitizer" do
    test "Should allow valid mathml through" do
      expressions = [
        "<math><mn>4</mn><mi>x</mi><mo>+</mo><mn>4</mn><mo>=</mo><mo>(</mo><mn>2</mn><mo>+</mo><mn>2</mn><mo>)</mo><mi>x</mi><mo>+</mo><mn>2</mn><mn>2</mn></math>",
        "<math><mi>f</mi><mo>:</mo><mn>ℝ</mn><mo>→</mo><mn>[-1,1]</mn></math>",
        "<math><mi>f</mi><mo>(</mo><mi>x</mi><mo>)</mo><mo>=</mo><mi>sin</mi><mi>x</mi></math>",
        "<math><mfrac><mi>x</mi><mi>y</mi></mfrac></math>"
      ]

      for mml <- expressions do
        assert Scrubber.scrub(mml, MathMLSanitizer) == mml
      end
    end

    test "Should add in missing closing tag" do
      assert Scrubber.scrub("<math><mfrac><mi>x</mi><mi>y</mi></mfrac>", MathMLSanitizer) ==
               "<math><mfrac><mi>x</mi><mi>y</mi></mfrac></math>"
    end

    test "Should replace safe entitites and leave unsafe ones" do
      assert Scrubber.scrub("<math><mi>&amp;&alpha;</mi></math>", MathMLSanitizer) ==
               "<math><mi>&amp;α</mi></math>"
    end

    test "Should strip unknown attributes" do
      assert Scrubber.scrub("<math><mi foobar=\"1\">1</mi></math>", MathMLSanitizer) ==
               "<math><mi>1</mi></math>"
    end

    test "Should allow known attributes" do
      assert Scrubber.scrub("<math><mi id=\"hello\">1</mi></math>", MathMLSanitizer) ==
               "<math><mi id=\"hello\">1</mi></math>"
    end

    test "Should prevent unsafe protocols" do
      assert Scrubber.scrub(
               "<semantics src=\"javascript:alert('hi')\"></semantics>",
               MathMLSanitizer
             ) ==
               "<semantics></semantics>"
    end

    test "Should allow safe protocols" do
      assert Scrubber.scrub(
               "<semantics src=\"https://some-site.com\"></semantics>",
               MathMLSanitizer
             ) ==
               "<semantics src=\"https://some-site.com\"></semantics>"
    end

    test "Should strip unknown tags" do
      assert Scrubber.scrub(
               "<script>alert('hi');</script>",
               MathMLSanitizer
             ) ==
               "alert('hi');"

      assert Scrubber.scrub(
               "<b>Bold tags can't go here</b>",
               MathMLSanitizer
             ) ==
               "Bold tags can't go here"

      assert Scrubber.scrub(
               "<foobar>Foobar tags don't exist</foobar>",
               MathMLSanitizer
             ) ==
               "Foobar tags don't exist"
    end
  end
end
