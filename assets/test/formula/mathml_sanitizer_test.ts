import { sanitizeMathML } from '../../src/utils/mathmlSanitizer';

describe('MathML sanitizer', () => {
  test('Should allow valid mathml through', () => {
    const expressions = [
      '<math><mn>4</mn><mi>x</mi><mo>+</mo><mn>4</mn><mo>=</mo><mo>(</mo><mn>2</mn><mo>+</mo><mn>2</mn><mo>)</mo><mi>x</mi><mo>+</mo><mn>2</mn><mn>2</mn></math>',
      '<math><mi>f</mi><mo>:</mo><mn>ℝ</mn><mo>→</mo><mn>[-1,1]</mn></math>',
      '<math><mi>f</mi><mo>(</mo><mi>x</mi><mo>)</mo><mo>=</mo><mi>sin</mi><mi>x</mi></math>',
      '<math><mfrac><mi>x</mi><mi>y</mi></mfrac></math>',
    ];

    for (const mml of expressions) {
      expect(sanitizeMathML(mml)).toEqual(mml);
    }
  });

  test('Should add in missing closing tag', () => {
    expect(sanitizeMathML('<math><mfrac><mi>x</mi><mi>y</mi></mfrac>')).toEqual(
      '<math><mfrac><mi>x</mi><mi>y</mi></mfrac></math>',
    );
  });

  test('Should replace safe entitites and leave unsafe ones', () => {
    expect(sanitizeMathML('<math><mi>&amp;&alpha;</mi></math>')).toEqual(
      '<math><mi>&amp;α</mi></math>',
    );
  });

  test('Should strip unknown attributes', () => {
    expect(sanitizeMathML('<math><mi foobar="1">1</mi></math>')).toEqual('<math><mi>1</mi></math>');
  });

  test('Should allow known attributes', () => {
    expect(sanitizeMathML('<math><mi id="hello">1</mi></math>')).toEqual(
      '<math><mi id="hello">1</mi></math>',
    );
  });

  test('Should prevent unsafe protocols', () => {
    expect(sanitizeMathML('<semantics src="javascript:alert(\'hi\')"></semantics>')).toEqual(
      '<semantics></semantics>',
    );

    expect(
      sanitizeMathML('<semantics definitionURL="javascript:alert(\'hi\')"></semantics>'),
    ).toEqual('<semantics></semantics>');
  });

  test('Should allow safe protocols', () => {
    expect(sanitizeMathML('<semantics src="https://some-site.com"></semantics>')).toEqual(
      '<semantics src="https://some-site.com"></semantics>',
    );

    expect(sanitizeMathML('<semantics definitionURL="https://some-site.com"></semantics>')).toEqual(
      '<semantics definitionurl="https://some-site.com"></semantics>',
    );
  });

  test('Should strip unknown tags', () => {
    // This is slightly different behavior than the elixir version.
    // The sanitizeMathML library will get rid of all the contents of the <script> whereas the
    // HtmlSanitizeEx elixir library will strip the tag and leave the contents. Either version
    // is still safe, and as far as I can tell, it's just the script tag treated special here.
    expect(sanitizeMathML("<script>alert('hi');</script>")).toEqual('');

    expect(sanitizeMathML("<b>Bold tags can't go here</b>")).toEqual("Bold tags can't go here");

    expect(sanitizeMathML("<foobar>Foobar tags don't exist</foobar>")).toEqual(
      "Foobar tags don't exist",
    );
  });
});
//sanitizeMathML
