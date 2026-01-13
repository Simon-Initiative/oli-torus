import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import { PaginationControls } from 'components/misc/PaginationControls';

const setupMatchMedia = (matches: boolean) => {
  window.matchMedia = jest.fn().mockImplementation((query: string) => {
    const listeners: Array<(event: MediaQueryListEvent) => void> = [];
    return {
      matches,
      media: query,
      addEventListener: (_: 'change', listener: (event: MediaQueryListEvent) => void) => {
        listeners.push(listener);
      },
      removeEventListener: (_: 'change', listener: (event: MediaQueryListEvent) => void) => {
        const index = listeners.indexOf(listener);
        if (index >= 0) {
          listeners.splice(index, 1);
        }
      },
      addListener: (_listener: (event: MediaQueryListEvent) => void) => {},
      removeListener: (_listener: (event: MediaQueryListEvent) => void) => {},
      dispatchEvent: (_event: MediaQueryListEvent) => true,
      onchange: null,
    } as MediaQueryList;
  });
};

const renderPaginationControls = (pageCount: number, initiallyVisible: number[] = [0]) => {
  const elements: React.ReactNode[] = [];
  for (let i = 0; i < pageCount; i += 1) {
    elements.push(<div key={`break-${i}`} className="content-break" />);
    elements.push(<div key={`content-${i}`}>Page {i + 1} content</div>);
  }

  return render(
    <div>
      <div className="elements">{elements}</div>
      <div>
        <PaginationControls
          forId="pagination-test"
          paginationMode="normal"
          sectionSlug="section-slug"
          pageAttemptGuid="attempt-guid"
          initiallyVisible={initiallyVisible}
        />
      </div>
    </div>,
  );
};

describe('PaginationControls', () => {
  afterEach(() => {
    // @ts-expect-error - cleanup test-only override
    delete window.matchMedia;
  });

  it('condenses page numbers on mobile to first, active, and last pages with ellipses', async () => {
    setupMatchMedia(false);
    renderPaginationControls(6, [3]);

    await waitFor(() => {
      expect(screen.getByRole('button', { name: '1' })).toBeInTheDocument();
    });

    expect(screen.getByRole('button', { name: '4' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '6' })).toBeInTheDocument();
    expect(screen.getAllByText('...')).toHaveLength(2);

    expect(screen.queryByRole('button', { name: '3' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: '5' })).not.toBeInTheDocument();
  });

  it('shows first two and last two pages on mobile when current is near the ends', async () => {
    setupMatchMedia(false);
    renderPaginationControls(6, [0]);

    await waitFor(() => {
      expect(screen.getByRole('button', { name: '1' })).toBeInTheDocument();
    });

    expect(screen.getByRole('button', { name: '2' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '5' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '6' })).toBeInTheDocument();
    expect(screen.getAllByText('...')).toHaveLength(1);

    expect(screen.queryByRole('button', { name: '3' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: '4' })).not.toBeInTheDocument();
  });

  it('shows all page numbers on desktop', async () => {
    setupMatchMedia(true);
    renderPaginationControls(6);

    await waitFor(() => {
      expect(screen.getByRole('button', { name: '1' })).toBeInTheDocument();
    });

    for (const label of ['1', '2', '3', '4', '5', '6']) {
      expect(screen.getByRole('button', { name: label })).toBeInTheDocument();
    }
    expect(screen.queryByText('...')).not.toBeInTheDocument();
  });
});
