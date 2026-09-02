import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { ObjectivesSelection } from 'components/resource/objectives/ObjectivesSelection';
import { Objective } from 'data/content/objective';

const objectives: Objective[] = [
  { id: 1, title: 'Parent', parentIds: null },
  { id: 2, title: 'Child', parentIds: [1] },
];

const renderSearchOnlySelector = (selected: number[] = []) =>
  render(
    <ObjectivesSelection
      objectives={objectives}
      selected={selected}
      editMode={true}
      projectSlug="project"
      attachmentType="activity"
      loWellFormed={true}
      onEdit={jest.fn()}
      onRegisterNewObjective={jest.fn()}
    />,
  );

describe('well-formed activity objective search', () => {
  it('identifies the input as search and explains when no eligible objective matches', () => {
    renderSearchOnlySelector();

    const input = screen.getByRole('textbox');
    expect(input).toHaveAttribute('placeholder', 'Search learning objectives...');

    fireEvent.change(input, { target: { value: 'No matching objective' } });

    expect(screen.getByText('No eligible learning objectives found.')).toBeInTheDocument();
  });

  it('clears unmatched search text on blur', () => {
    renderSearchOnlySelector([2]);

    const input = screen.getByRole('textbox');
    fireEvent.change(input, { target: { value: 'Unsaved search' } });
    fireEvent.blur(input);

    expect(screen.getByRole('textbox')).toHaveValue('');
    expect(screen.getByText('Child')).toBeInTheDocument();
  });

  it('clears unmatched search text on Escape', () => {
    renderSearchOnlySelector();

    const input = screen.getByRole('textbox');
    fireEvent.change(input, { target: { value: 'Unsaved search' } });
    fireEvent.keyDown(input, { key: 'Escape', keyCode: 27 });

    expect(screen.getByRole('textbox')).toHaveValue('');
  });
});
