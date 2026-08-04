import React from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { SelectModal } from 'components/modal/SelectModal';

const jqueryModal = {
  modal: jest.fn(),
  on: jest.fn(),
};

beforeEach(() => {
  jqueryModal.modal.mockClear();
  jqueryModal.on.mockClear();

  const jquery = jest.fn(() => jqueryModal);
  (window as any).$ = jquery;
  (global as any).$ = jquery;
});

const options = [{ value: 'one', title: 'Option one' }];

test('announces option-loading errors', async () => {
  render(
    <SelectModal
      title="Choose an option"
      description="Options"
      onFetchOptions={() => Promise.reject(new Error('network unavailable'))}
      onDone={jest.fn()}
      onCancel={jest.fn()}
    />,
  );

  const alert = await screen.findByRole('alert');

  expect(alert).toHaveTextContent('network unavailable');
  expect(screen.getByRole('button', { name: 'Select' })).toHaveAttribute(
    'aria-describedby',
    alert.id,
  );
});

test('announces submission errors', async () => {
  render(
    <SelectModal
      title="Choose an option"
      description="Options"
      onFetchOptions={() => Promise.resolve(options)}
      onDone={() => Promise.reject(new Error('selection failed'))}
      onCancel={jest.fn()}
    />,
  );

  const select = await screen.findByRole('combobox');
  fireEvent.change(select, { target: { value: 'one' } });
  fireEvent.click(screen.getByRole('button', { name: 'Select' }));

  const alert = await screen.findByRole('alert');
  expect(alert).toHaveTextContent('selection failed');

  await waitFor(() =>
    expect(screen.getByRole('button', { name: 'Select' })).toHaveAttribute(
      'aria-describedby',
      alert.id,
    ),
  );
});
