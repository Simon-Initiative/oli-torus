import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { SelectModal } from 'components/modal/SelectModal';

beforeAll(() => {
  const jq: any = () => ({ modal: () => undefined, on: () => undefined });
  (window as any).$ = jq;
  (global as any).$ = jq;
});

afterAll(() => {
  delete (window as any).$;
  delete (global as any).$;
});

describe('SelectModal', () => {
  it('shows an error and remains usable when submission fails', async () => {
    const onDone = jest.fn().mockRejectedValue(new Error('Decision point request failed'));

    render(
      <SelectModal
        title="Select decision point"
        description="Decision point"
        onFetchOptions={() => Promise.resolve([{ value: 1, title: 'Decision point A' }])}
        onDone={onDone}
        onCancel={jest.fn()}
      />,
    );

    fireEvent.change(await screen.findByRole('combobox'), { target: { value: '1' } });
    fireEvent.click(screen.getByRole('button', { name: 'Select' }));

    expect(await screen.findByText('Error: Decision point request failed')).toBeInTheDocument();
    await waitFor(() => expect(screen.getByRole('button', { name: 'Select' })).toBeEnabled());
  });
});
