import React from 'react';
import { render } from '@testing-library/react';
import {
  MathJaxLatexFormula,
  MathJaxMathMLFormula,
} from '../../src/components/common/MathJaxFormula';

describe('MathJaxFormula', () => {
  let restore: any = undefined;

  beforeEach(() => {
    restore = window.MathJax;
    window.MathJax = {
      startup: {
        promise: Promise.resolve(),
      },
      typesetPromise: jest.fn().mockResolvedValue(undefined),
    };
  });

  afterEach(() => {
    window.MathJax = restore;
  });

  describe('MathJaxLatexFormula', () => {
    test('renders a mathml block expression', () => {
      const { container } = render(
        <MathJaxMathMLFormula
          id="1"
          src="<math><mfrac><mi>x</mi><mi>y</mi></mfrac></math>"
          inline={false}
        />,
      );
      const e = container.querySelector('span');
      expect(e).toBeTruthy();
      expect(e).toHaveAttribute('class', 'formula');
      expect(e).toContainHTML('<math><mfrac><mi>x</mi><mi>y</mi></mfrac></math>');
    });

    test('renders a mathml inline expression', () => {
      const { container } = render(
        <MathJaxMathMLFormula
          id="1"
          src="<math><mfrac><mi>x</mi><mi>y</mi></mfrac></math>"
          inline={true}
        />,
      );
      const e = container.querySelector('span');
      expect(e).toBeTruthy();
      expect(e).toHaveAttribute('class', 'formula-inline');
      expect(e).toContainHTML('<math><mfrac><mi>x</mi><mi>y</mi></mfrac></math>');
    });

    test('does not expose an xss vulnerability', () => {
      const { container } = render(
        <MathJaxMathMLFormula
          id="1"
          src="<math><script>alert('breaking the law');</script></math>"
          inline={true}
        />,
      );
      const e = container.querySelector('span');
      expect(e).toBeTruthy();
      expect(e).toHaveAttribute('class', 'formula-inline');
      expect(e).toContainHTML('<math></math>');
    });
  });

  describe('MathJaxLatexFormula', () => {
    test('renders a latex block expression', () => {
      const { container } = render(
        <MathJaxLatexFormula id="1" src="x^2 + y^2 = z^2" inline={false} />,
      );

      const e = container.querySelector('span');
      expect(e).toBeTruthy();
      expect(e).toHaveAttribute('class', 'formula');
      expect(e).toHaveTextContent('\\[x^2 + y^2 = z^2\\]');
    });

    test('renders a latex inline expression', () => {
      const { container } = render(
        <MathJaxLatexFormula id="1" src="x^2 + y^2 = z^2" inline={true} />,
      );

      const e = container.querySelector('span');
      expect(e).toBeTruthy();
      expect(e).toHaveAttribute('class', 'formula-inline');
      expect(e).toHaveTextContent('\\(x^2 + y^2 = z^2\\)');
    });

    test('does not expose an xss vulnerability', () => {
      const { container } = render(
        <MathJaxLatexFormula
          id="1"
          src="<script>alert('Breaking the law');</script>"
          inline={true}
        />,
      );

      const e = container.querySelector('span');
      expect(e).toBeTruthy();
      expect(e).toHaveAttribute('class', 'formula-inline');
      expect(e).toContainHTML(
        '<span aria-label="" class="formula-inline">\\(&lt;script&gt;alert(\'Breaking the law\');&lt;/script&gt;\\)</span>',
      );
    });

    test('render a formula with altText', () => {
      const { container } = render(
        <MathJaxLatexFormula
          id="1"
          src="x^2 + y^2 = z^2"
          formulaAltText="x squared plus y squared equals z squared"
          inline={true}
        />,
      );

      const e = container.querySelector('span');
      expect(e).toBeTruthy();
      expect(e).toHaveAttribute('class', 'formula-inline');
      expect(e).toContainHTML(
        '<span aria-label="x squared plus y squared equals z squared" class="formula-inline">\\(x^2 + y^2 = z^2\\)</span>',
      );
    });
  });
});
