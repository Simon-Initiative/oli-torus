import React from 'react';
import { act, cleanup, render, screen, waitFor, within } from '@testing-library/react';
import PopupWindow from 'components/parts/janus-popup/PopupWindow';

jest.mock('components/activities/adaptive/components/delivery/PartsLayoutRenderer', () => ({
  __esModule: true,
  default: function MockPartsLayoutRenderer({
    parts,
  }: {
    parts: Array<{ id: string; content: React.ReactNode }>;
  }) {
    return (
      <>
        {parts.map((part) => (
          <div key={part.id}>{part.content}</div>
        ))}
      </>
    );
  },
}));

const parts = [
  { id: 'first', type: 'janus-text-flow', content: <p>First paragraph.</p> },
  {
    id: 'second',
    type: 'janus-text-flow',
    content: (
      <p>
        Water is H<sub>2</sub>O; area is m<sup>2</sup>.
      </p>
    ),
  },
  {
    id: 'image',
    type: 'janus-image',
    content: <img src="/test-water.png" alt="Diagram of a water molecule" />,
  },
];

const windowElement = (accessibleName = 'Chemistry details') => (
  <PopupWindow
    accessibleName={accessibleName}
    config={{ width: 300, height: 200, x: 0, y: 0, z: 1000 }}
    parts={parts}
    context={{ currentActivity: 'test-activity', mode: 'delivery' }}
  />
);

const descriptionFor = (dialog: HTMLElement): HTMLElement => {
  const id = dialog.getAttribute('aria-describedby');
  expect(id?.trim()).toBeTruthy();
  const description = id ? document.getElementById(id) : null;
  expect(description).toBeInTheDocument();
  if (!description) {
    throw new Error('Dialog must reference an existing description element');
  }
  expect(dialog).toContainElement(description);
  return description;
};

const readingFor = (dialog: HTMLElement): HTMLElement => {
  const text = dialog.querySelector<HTMLElement>('p[tabindex="-1"]');
  expect(text).toBeInTheDocument();
  if (!text) throw new Error('Informational popup must have an initial reading target');
  return text;
};

describe('PopupWindow accessibility', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    cleanup();
    jest.clearAllTimers();
    jest.useRealTimers();
  });

  test('names the dialog and provides the complete text as one initial reading target', () => {
    render(windowElement());

    const dialog = screen.getByRole('dialog');
    expect(dialog.getAttribute('aria-label')?.trim()).toBeTruthy();
    expect(dialog).toHaveAttribute('aria-label', 'Chemistry details');
    expect(dialog).toHaveAccessibleName('Chemistry details');

    const description = readingFor(dialog);
    expect(description).not.toHaveAttribute('hidden');
    expect(description).toHaveClass('sr-only');
    expect(dialog).not.toHaveAttribute('aria-describedby');
    expect(description.childNodes).toHaveLength(1);
    expect(description.firstChild?.nodeType).toBe(Node.TEXT_NODE);
    expect(description).toHaveTextContent('First paragraph.');
    expect(description).toHaveTextContent('Water is H2O; area is m2.');
    expect(
      within(dialog).getByRole('img', { name: 'Diagram of a water molecule' }),
    ).toBeInTheDocument();
    act(() => {
      jest.advanceTimersByTime(20);
    });
    expect(description).toHaveFocus();
    expect(within(description).queryByRole('button', { name: 'Close' })).toBeNull();
    expect(within(dialog).getByRole('button', { name: 'Close' })).toBeInTheDocument();
  });

  test('updates the description when a nested part renders after mount', async () => {
    const { rerender } = render(
      <PopupWindow
        accessibleName="Async content"
        config={{}}
        context={{ currentActivity: 'test', mode: 'delivery' }}
        parts={[{ id: 'text', type: 'janus-text-flow', content: null }]}
      />,
    );

    rerender(
      <PopupWindow
        accessibleName="Async content"
        config={{}}
        context={{ currentActivity: 'test', mode: 'delivery' }}
        parts={[{ id: 'text', type: 'janus-text-flow', content: <p>Last paragraph.</p> }]}
      />,
    );

    await waitFor(() => {
      expect(readingFor(screen.getByRole('dialog'))).toHaveTextContent('Last paragraph.');
    });
  });

  test('preserves the rendered description for interactive popup content', () => {
    render(
      <PopupWindow
        accessibleName="Interactive content"
        config={{}}
        context={{ currentActivity: 'test', mode: 'delivery' }}
        parts={[{ id: 'link', type: 'janus-text-flow', content: <a href="/help">Help</a> }]}
      />,
    );

    const dialog = screen.getByRole('dialog');
    const description = descriptionFor(dialog);
    expect(description).not.toHaveAttribute('hidden');
    expect(within(description).getByRole('link', { name: 'Help' })).toBeVisible();
    act(() => {
      jest.advanceTimersByTime(20);
    });
    expect(dialog).toHaveFocus();
  });

  test.each([false, true])(
    'handles late text without stealing focus after the user moves: %s',
    (moveToClose) => {
      const popup = (content: React.ReactNode) => (
        <PopupWindow
          accessibleName="Late content"
          config={{}}
          context={{ currentActivity: 'test', mode: 'delivery' }}
          parts={[{ id: 'text', type: 'janus-text-flow', content }]}
        />
      );
      const { rerender } = render(popup(null));
      act(() => {
        jest.advanceTimersByTime(20);
      });
      const dialog = screen.getByRole('dialog');
      expect(dialog).toHaveFocus();
      const close = screen.getByRole('button', { name: 'Close' });
      if (moveToClose) close.focus();

      rerender(popup(<p>Complete late content.</p>));
      act(() => {
        jest.advanceTimersByTime(20);
      });
      expect(moveToClose ? close : readingFor(dialog)).toHaveFocus();

      close.focus();
      rerender(popup(<p>Updated content.</p>));
      act(() => {
        jest.advanceTimersByTime(20);
      });
      expect(close).toHaveFocus();
    },
  );

  test('keeps the reading target stable across rerenders', () => {
    const { rerender } = render(windowElement());
    const originalId = readingFor(screen.getByRole('dialog')).id;

    rerender(windowElement('Updated chemistry details'));

    const dialog = screen.getByRole('dialog', { name: 'Updated chemistry details' });
    expect(readingFor(dialog)).toHaveAttribute('id', originalId);
    expect(readingFor(dialog)).toHaveTextContent('First paragraph.');
  });

  test('gives simultaneous dialogs separate reading targets', () => {
    render(
      <>
        {windowElement('First dialog')}
        {windowElement('Second dialog')}
      </>,
    );

    const first = screen.getByRole('dialog', { name: 'First dialog' });
    const second = screen.getByRole('dialog', { name: 'Second dialog' });
    expect(readingFor(first).id).not.toBe(readingFor(second).id);
    expect(readingFor(first)).not.toBe(readingFor(second));
  });
});
