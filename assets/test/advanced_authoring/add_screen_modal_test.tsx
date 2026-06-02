import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import {
  AddScreenModal,
  EXPORT_EXAMPLES_NOTE,
} from 'apps/authoring/components/ScreenList/AddScreenModal';

jest.mock('apps/authoring/components/AdvancedAuthoringModal', () => ({
  AdvancedAuthoringModal: ({
    children,
    show,
    onHide,
  }: {
    children: React.ReactNode;
    show?: boolean;
    onHide?: () => void;
  }) =>
    show ? (
      <div data-testid="add-screen-modal">
        {children}
        <button type="button" onClick={onHide}>
          Close
        </button>
      </div>
    ) : null,
}));

jest.mock('apps/authoring/components/Flowchart/screen-icons/screen-icons', () => ({
  ScreenIcon: () => <span data-testid="screen-icon" />,
}));

describe('AddScreenModal', () => {
  it('shows the export examples note in the footer after a screen type is selected', () => {
    render(<AddScreenModal onCancel={jest.fn()} onCreate={jest.fn(async () => {})} />);

    expect(screen.queryByText(EXPORT_EXAMPLES_NOTE)).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: /Instructional Screen/i }));

    expect(screen.getByText(EXPORT_EXAMPLES_NOTE)).toBeInTheDocument();
    expect(document.querySelector('.add-screen-modal-footer-note-icon')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^Next/i })).toBeInTheDocument();
  });

  it('keeps the export examples note visible after title and screen type are both entered', () => {
    render(<AddScreenModal onCancel={jest.fn()} onCreate={jest.fn(async () => {})} />);

    fireEvent.change(screen.getByPlaceholderText('Add screen title...'), {
      target: { value: 'My Screen' },
    });
    fireEvent.click(screen.getByRole('button', { name: /Slider/i }));

    expect(screen.getByText(EXPORT_EXAMPLES_NOTE)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^Next/i })).toBeInTheDocument();
  });

  it('shows validation flow when Next is clicked without a title', () => {
    render(<AddScreenModal onCancel={jest.fn()} onCreate={jest.fn(async () => {})} />);

    fireEvent.click(screen.getByRole('button', { name: /Hub and Spoke/i }));
    fireEvent.click(screen.getByRole('button', { name: /^Next/i }));

    expect(screen.getByText(/Are you sure\?/i)).toBeInTheDocument();
    expect(screen.getByText(/screen title may be helpful/i)).toBeInTheDocument();
    expect(screen.queryByText(EXPORT_EXAMPLES_NOTE)).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^Continue/i })).toBeInTheDocument();
  });

  it('shows loading state and waits for onCreate before closing', async () => {
    let resolveCreate: (() => void) | undefined;
    const onCreate = jest.fn(
      () =>
        new Promise<void>((resolve) => {
          resolveCreate = resolve;
        }),
    );
    const onCancel = jest.fn();

    render(<AddScreenModal onCancel={onCancel} onCreate={onCreate} />);

    fireEvent.change(screen.getByPlaceholderText('Add screen title...'), {
      target: { value: 'New Lesson Screen' },
    });
    fireEvent.click(screen.getByRole('button', { name: /Instructional Screen/i }));
    fireEvent.click(screen.getByRole('button', { name: /^Next/i }));

    expect(onCreate).toHaveBeenCalledWith('New Lesson Screen', 'blank_screen');
    expect(screen.getByRole('status')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /^Next/i })).toBeDisabled();
    expect(onCancel).not.toHaveBeenCalled();

    resolveCreate?.();
    await waitFor(() => {
      expect(screen.queryByRole('status')).not.toBeInTheDocument();
    });
  });
});
