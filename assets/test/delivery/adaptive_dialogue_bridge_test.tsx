import React from 'react';
import '@testing-library/jest-dom';
import { render } from '@testing-library/react';
import { AdaptiveDialogueBridge } from 'apps/delivery/components/AdaptiveDialogueBridge';

describe('AdaptiveDialogueBridge', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('dispatches the adaptive screen change event when enabled with a guid', () => {
    const dispatchEvent = jest.spyOn(window, 'dispatchEvent');

    render(<AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-1" enabled={true} />);

    expect(dispatchEvent).toHaveBeenCalledTimes(1);

    const dispatchedEvent = dispatchEvent.mock.calls[0][0] as CustomEvent;

    expect(dispatchedEvent.type).toBe('oli:adaptive-screen-changed');
    expect(dispatchedEvent.detail).toEqual({ activityAttemptGuid: 'attempt-guid-1' });
  });

  it('only dispatches when supported mode is enabled and the guid changes', () => {
    const dispatchEvent = jest.spyOn(window, 'dispatchEvent');

    const { rerender } = render(
      <AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-1" enabled={false} />,
    );

    expect(dispatchEvent).not.toHaveBeenCalled();

    rerender(<AdaptiveDialogueBridge activityAttemptGuid={undefined} enabled={true} />);
    expect(dispatchEvent).not.toHaveBeenCalled();

    rerender(<AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-1" enabled={true} />);
    expect(dispatchEvent).toHaveBeenCalledTimes(1);

    rerender(<AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-1" enabled={true} />);
    expect(dispatchEvent).toHaveBeenCalledTimes(1);

    rerender(<AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-2" enabled={true} />);
    expect(dispatchEvent).toHaveBeenCalledTimes(2);
  });

  it('responds to an adaptive screen sync request with the latest guid', () => {
    const dispatchEvent = jest.spyOn(window, 'dispatchEvent');

    render(<AdaptiveDialogueBridge activityAttemptGuid="attempt-guid-1" enabled={true} />);
    dispatchEvent.mockClear();

    window.dispatchEvent(new CustomEvent('oli:adaptive-screen-sync-request'));

    expect(dispatchEvent).toHaveBeenCalledTimes(2);

    const dispatchedEvent = dispatchEvent.mock.calls[1][0] as CustomEvent;

    expect(dispatchedEvent.type).toBe('oli:adaptive-screen-changed');
    expect(dispatchedEvent.detail).toEqual({ activityAttemptGuid: 'attempt-guid-1' });
  });
});
