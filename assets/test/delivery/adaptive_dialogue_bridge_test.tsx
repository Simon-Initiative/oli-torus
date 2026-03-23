import React from 'react';
import '@testing-library/jest-dom';
import { render } from '@testing-library/react';
import { AdaptiveDialogueBridge } from 'apps/delivery/components/AdaptiveDialogueBridge';

describe('AdaptiveDialogueBridge', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('dispatches an adaptive screen ready event when enabled with a guid', () => {
    const dispatchEvent = jest.spyOn(window, 'dispatchEvent');

    render(<AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-1" enabled={true} />);

    expect(dispatchEvent).toHaveBeenCalledTimes(1);

    const dispatchedEvent = dispatchEvent.mock.calls[0][0] as CustomEvent;

    expect(dispatchedEvent.type).toBe('oli:adaptive-screen-ready');
  });

  it('only dispatches screen change events when supported mode is enabled and the guid changes', () => {
    const dispatchEvent = jest.spyOn(window, 'dispatchEvent');

    const { rerender } = render(
      <AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-1" enabled={false} />,
    );

    expect(dispatchEvent).not.toHaveBeenCalled();

    rerender(<AdaptiveDialogueBridge activityAttemptGuid={undefined} enabled={true} />);
    expect(dispatchEvent).not.toHaveBeenCalled();

    rerender(<AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-1" enabled={true} />);
    expect(dispatchEvent).toHaveBeenCalledTimes(1);
    expect((dispatchEvent.mock.calls[0][0] as CustomEvent).type).toBe('oli:adaptive-screen-ready');

    rerender(<AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-1" enabled={true} />);
    expect(dispatchEvent).toHaveBeenCalledTimes(1);

    rerender(<AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-2" enabled={true} />);
    expect(dispatchEvent).toHaveBeenCalledTimes(2);
    expect((dispatchEvent.mock.calls[1][0] as CustomEvent).type).toBe(
      'oli:adaptive-screen-changed',
    );
  });

  it('responds to an adaptive screen sync request with the latest guid', () => {
    const dispatchEvent = jest.spyOn(window, 'dispatchEvent');

    render(<AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-1" enabled={true} />);
    expect((dispatchEvent.mock.calls[0][0] as CustomEvent).type).toBe('oli:adaptive-screen-ready');

    window.dispatchEvent(new CustomEvent('oli:adaptive-screen-sync-request'));

    const adaptiveScreenChangedEvents = dispatchEvent.mock.calls
      .map(([event]) => event as CustomEvent)
      .filter((event) => event.type === 'oli:adaptive-screen-changed');

    expect(adaptiveScreenChangedEvents).toHaveLength(1);

    const dispatchedEvent = adaptiveScreenChangedEvents[0];

    expect(dispatchedEvent.type).toBe('oli:adaptive-screen-changed');
    expect(dispatchedEvent.detail).toEqual({ activityAttemptGuid: 'attempt-guid-1' });
  });

  it('mirrors adaptive sync events onto the parent window when embedded in an iframe', () => {
    const parentWindow = {
      addEventListener: jest.fn(),
      dispatchEvent: jest.fn(),
      removeEventListener: jest.fn(),
    };

    jest.spyOn(window, 'parent', 'get').mockReturnValue(parentWindow as unknown as Window);

    render(<AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-1" enabled={true} />);

    expect(parentWindow.dispatchEvent).toHaveBeenCalledTimes(1);
    expect((parentWindow.dispatchEvent as jest.Mock).mock.calls[0][0].type).toBe(
      'oli:adaptive-screen-ready',
    );

    const syncRequestHandler = (parentWindow.addEventListener as jest.Mock).mock.calls.find(
      ([eventName]) => eventName === 'oli:adaptive-screen-sync-request',
    )?.[1];

    expect(syncRequestHandler).toBeDefined();

    syncRequestHandler(new CustomEvent('oli:adaptive-screen-sync-request'));

    const changedEvents = (parentWindow.dispatchEvent as jest.Mock).mock.calls
      .map(([event]) => event as CustomEvent)
      .filter((event) => event.type === 'oli:adaptive-screen-changed');

    expect(changedEvents).toHaveLength(1);
    expect(changedEvents[0].detail).toEqual({ activityAttemptGuid: 'attempt-guid-1' });
  });
});
