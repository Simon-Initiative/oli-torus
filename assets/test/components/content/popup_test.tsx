import React from 'react';
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { Popup } from 'components/content/Popup';
import { Model } from 'data/content/model/elements/factories';
import { Popup as PopupModel } from 'data/content/model/elements/types';

describe('Popup', () => {
  const setupMatchMedia = ({ hover, coarse }: { hover: boolean; coarse: boolean }) => {
    window.matchMedia = jest.fn().mockImplementation((query: string) => {
      const listeners: Array<(event: MediaQueryListEvent) => void> = [];
      const matches =
        query === '(hover: hover) and (pointer: fine)'
          ? hover
          : query === '(pointer: coarse)'
          ? coarse
          : false;

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

  const renderPopup = (modelOverrides: Partial<PopupModel> = {}) => {
    const basePopup = Model.popup();
    const popupModel: PopupModel = {
      ...basePopup,
      content: [Model.p('More info')],
      audioSrc: undefined,
      ...modelOverrides,
    };

    return render(
      <Popup popup={popupModel} popupContent={<span>More info</span>}>
        Key notion
      </Popup>,
    );
  };

  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.clearAllTimers();
    jest.useRealTimers();
    cleanup();
    // @ts-expect-error - cleanup test-only override
    delete window.matchMedia;
  });

  it('opens on hover and closes after a short delay on pointer devices', () => {
    setupMatchMedia({ hover: true, coarse: false });

    renderPopup({ trigger: 'hover' });

    const anchor = screen.getByRole('button', { name: /key notion/i });

    fireEvent.mouseEnter(anchor);
    expect(screen.getByRole('tooltip')).toBeInTheDocument();

    fireEvent.mouseLeave(anchor);
    act(() => {
      jest.advanceTimersByTime(1000);
    });

    expect(screen.queryByRole('tooltip')).not.toBeInTheDocument();
  });

  it('opens on tap and renders a close control on touch devices', () => {
    setupMatchMedia({ hover: false, coarse: true });

    renderPopup({ trigger: 'hover' });

    const anchor = screen.getByRole('button', { name: /key notion/i });

    fireEvent.click(anchor);
    expect(screen.getByRole('dialog')).toBeInTheDocument();

    const closeButton = screen.getByRole('button', { name: /close key notion popup/i });
    fireEvent.click(closeButton);

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('does not toggle open on click for hover-triggered popups on desktop', () => {
    setupMatchMedia({ hover: true, coarse: false });

    renderPopup({ trigger: 'hover' });

    const anchor = screen.getByRole('button', { name: /key notion/i });

    fireEvent.click(anchor);

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();

    fireEvent.mouseEnter(anchor);
    expect(screen.getByRole('tooltip')).toBeInTheDocument();
  });

  it('closes a previously opened popup when another opens', async () => {
    setupMatchMedia({ hover: true, coarse: false });

    const popupModelOne: PopupModel = {
      ...Model.popup(),
      trigger: 'hover',
      content: [Model.p('First info')],
      audioSrc: undefined,
    };

    const popupModelTwo: PopupModel = {
      ...Model.popup(),
      trigger: 'hover',
      content: [Model.p('Second info')],
      audioSrc: undefined,
    };

    render(
      <>
        <Popup popup={popupModelOne} popupContent={<span>First info</span>}>
          Alpha
        </Popup>
        <Popup popup={popupModelTwo} popupContent={<span>Second info</span>}>
          Beta
        </Popup>
      </>,
    );

    const firstAnchor = screen.getByRole('button', { name: /alpha/i });
    const secondAnchor = screen.getByRole('button', { name: /beta/i });

    fireEvent.mouseEnter(firstAnchor);
    expect(screen.getByRole('tooltip')).toHaveTextContent('Alpha');

    act(() => {
      fireEvent.mouseEnter(secondAnchor);
    });

    await waitFor(() => {
      const tooltips = screen.queryAllByRole('tooltip');
      expect(tooltips).toHaveLength(1);
      expect(tooltips[0]).toHaveTextContent('Beta');
    });
  });
});
