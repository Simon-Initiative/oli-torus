import React, { useEffect, useRef } from 'react';

interface AdaptiveDialogueBridgeProps {
  activityAttemptGuid?: string;
  enabled: boolean;
}

export const AdaptiveDialogueBridge: React.FC<AdaptiveDialogueBridgeProps> = ({
  activityAttemptGuid,
  enabled,
}) => {
  const previousActivityAttemptGuid = useRef<string | undefined>(undefined);

  const getEventTargets = () => {
    const targets: Window[] = [window];

    try {
      if (window.parent && window.parent !== window) {
        targets.push(window.parent);
      }
    } catch {
      // Ignore parent-window access if the browser treats it as cross-origin.
    }

    return targets;
  };

  const dispatchAdaptiveEvent = (event: CustomEvent) => {
    getEventTargets().forEach((target) => target.dispatchEvent(event));
  };

  const addAdaptiveEventListener = (eventName: string, listener: EventListener) => {
    getEventTargets().forEach((target) => target.addEventListener(eventName, listener));
  };

  const removeAdaptiveEventListener = (eventName: string, listener: EventListener) => {
    getEventTargets().forEach((target) => target.removeEventListener(eventName, listener));
  };

  useEffect(() => {
    const handleAdaptiveScreenSyncRequest = () => {
      if (!enabled || !activityAttemptGuid) {
        return;
      }

      dispatchAdaptiveEvent(
        new CustomEvent('oli:adaptive-screen-changed', {
          detail: { activityAttemptGuid },
        }),
      );
    };

    addAdaptiveEventListener('oli:adaptive-screen-sync-request', handleAdaptiveScreenSyncRequest);

    return () => {
      removeAdaptiveEventListener(
        'oli:adaptive-screen-sync-request',
        handleAdaptiveScreenSyncRequest,
      );
    };
  }, [activityAttemptGuid, enabled]);

  useEffect(() => {
    if (!enabled || !activityAttemptGuid) {
      previousActivityAttemptGuid.current = undefined;
      return;
    }

    if (!previousActivityAttemptGuid.current) {
      previousActivityAttemptGuid.current = activityAttemptGuid;
      dispatchAdaptiveEvent(new CustomEvent('oli:adaptive-screen-ready'));
      return;
    }

    if (previousActivityAttemptGuid.current !== activityAttemptGuid) {
      previousActivityAttemptGuid.current = activityAttemptGuid;
      dispatchAdaptiveEvent(
        new CustomEvent('oli:adaptive-screen-changed', {
          detail: { activityAttemptGuid },
        }),
      );
    }
  }, [activityAttemptGuid, enabled]);

  return null;
};
