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

  useEffect(() => {
    const handleAdaptiveScreenSyncRequest = () => {
      if (!enabled || !activityAttemptGuid) {
        return;
      }

      window.dispatchEvent(
        new CustomEvent('oli:adaptive-screen-changed', {
          detail: { activityAttemptGuid },
        }),
      );
    };

    window.addEventListener('oli:adaptive-screen-sync-request', handleAdaptiveScreenSyncRequest);

    return () => {
      window.removeEventListener(
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
      window.dispatchEvent(new CustomEvent('oli:adaptive-screen-ready'));
      return;
    }

    if (previousActivityAttemptGuid.current !== activityAttemptGuid) {
      previousActivityAttemptGuid.current = activityAttemptGuid;
      window.dispatchEvent(
        new CustomEvent('oli:adaptive-screen-changed', {
          detail: { activityAttemptGuid },
        }),
      );
    }
  }, [activityAttemptGuid, enabled]);

  return null;
};
