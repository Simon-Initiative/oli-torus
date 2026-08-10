import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import ItemEditorModal from '../../src/components/parts/janus-item-bank/ItemEditorModal';
import { GroupingItem } from '../../src/components/parts/janus-item-bank/schema';

jest.mock('../../src/apps/authoring/components/AdvancedAuthoringModal', () => {
  const mockReact = jest.requireActual('react');
  return {
    AdvancedAuthoringModal: ({ show, children }: { show: boolean; children: React.ReactNode }) =>
      show ? mockReact.createElement('div', null, children) : null,
  };
});

jest.mock('../../src/apps/authoring/components/Modal/MediaPickerModal', () => {
  const mockReact = jest.requireActual('react');
  return {
    MediaPickerModal: ({
      onUrlChanged,
      onOK,
    }: {
      onUrlChanged: (url: string) => void;
      onOK: () => void;
    }) =>
      mockReact.createElement(
        'div',
        null,
        mockReact.createElement(
          'button',
          {
            type: 'button',
            onClick: () => onUrlChanged('https://example.com/project/media/images?token=temporary'),
          },
          'Select soda image',
        ),
        mockReact.createElement(
          'button',
          {
            type: 'button',
            onClick: onOK,
          },
          'Use selected image',
        ),
      ),
  };
});

describe('Grouping item editor image accessibility', () => {
  test('preserves blank alt text through image selection, save, and reopen', () => {
    const onSave = jest.fn();
    const props = {
      show: true,
      initialItem: null,
      existingLabels: [],
      projectSlug: 'project',
      onSave,
      onCancel: jest.fn(),
    };
    const { rerender } = render(<ItemEditorModal {...props} />);

    fireEvent.click(screen.getByRole('button', { name: 'Image' }));
    fireEvent.change(screen.getByLabelText('Short label'), { target: { value: 'soda-id' } });
    fireEvent.change(screen.getByLabelText('Text'), { target: { value: 'A can of soda' } });
    fireEvent.click(screen.getByRole('button', { name: 'Choose image' }));
    fireEvent.click(screen.getByRole('button', { name: 'Select soda image' }));
    fireEvent.click(screen.getByRole('button', { name: 'Use selected image' }));

    expect(screen.getByLabelText('Alt text')).toHaveValue('');
    expect(screen.getByRole('img', { name: 'A can of soda' })).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Save' }));

    expect(onSave).toHaveBeenCalledTimes(1);
    const savedItem = onSave.mock.calls[0][0] as GroupingItem;
    expect(savedItem).toMatchObject({
      type: 'image',
      label: 'soda-id',
      text: 'A can of soda',
      imageSrc: 'https://example.com/project/media/images?token=temporary',
      alt: '',
    });

    rerender(<ItemEditorModal {...props} initialItem={savedItem} />);

    expect(screen.getByLabelText('Alt text')).toHaveValue('');
    expect(screen.getByRole('img', { name: 'A can of soda' })).toBeInTheDocument();
  });
});
