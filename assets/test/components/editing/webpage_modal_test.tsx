import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { WebpageModal } from 'components/editing/elements/webpage/WebpageModal';
import { Model } from 'data/content/model/elements/factories';

// Modal uses Bootstrap's jQuery plugin in an effect; stub it for jsdom.
beforeAll(() => {
  const jq: any = () => ({ modal: () => undefined, on: () => undefined });
  (window as any).$ = jq;
  (global as any).$ = jq;
});

const renderModal = (title?: string) => {
  const onDone = jest.fn();
  const model = { ...Model.webpage('https://phet.colorado.edu/sims/ph-scale'), title };

  render(<WebpageModal model={model} onDone={onDone} onCancel={jest.fn()} projectSlug="p1" />);

  return onDone;
};

describe('WebpageModal title', () => {
  it('shows the existing title and saves it trimmed', () => {
    const onDone = renderModal('Old title');
    const input = screen.getByLabelText('Title');

    expect(input).toHaveValue('Old title');

    fireEvent.change(input, { target: { value: '  PhET simulation: pH scale  ' } });
    fireEvent.click(screen.getByText('Save'));

    expect(onDone).toHaveBeenCalledWith(
      expect.objectContaining({ title: 'PhET simulation: pH scale' }),
    );
  });

  it('saves a blank title as undefined', () => {
    const onDone = renderModal('Old title');

    fireEvent.change(screen.getByLabelText('Title'), { target: { value: '   ' } });
    fireEvent.click(screen.getByText('Save'));

    expect(onDone.mock.calls[0][0].title).toBeUndefined();
  });
});
