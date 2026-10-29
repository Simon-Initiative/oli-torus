import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { FormulaToolbar } from 'components/editing/elements/formula/FormulaToolbar';

describe('FormulaToolbar', () => {
  it('uses the bg-primary token for the language strip background', () => {
    const { container } = render(<FormulaToolbar setSubtype={jest.fn()} subtype="latex" />);

    const toolbar = container.querySelector('.toolbar');
    expect(toolbar).toHaveClass('bg-Background-bg-primary');
  });

  it('marks the active language and switches subtype on click', () => {
    const setSubtype = jest.fn();
    render(<FormulaToolbar setSubtype={setSubtype} subtype="latex" />);

    expect(screen.getByRole('button', { name: 'Latex' })).toHaveClass('language-active');
    expect(screen.getByRole('button', { name: 'MathML' })).toHaveClass('language');

    fireEvent.click(screen.getByRole('button', { name: 'MathML' }));
    expect(setSubtype).toHaveBeenCalledWith('mathml');
  });
});
