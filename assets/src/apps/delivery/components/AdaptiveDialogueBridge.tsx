import React, { useEffect } from 'react';

interface AdaptiveDialogueBridgeProps {
  activityAttemptGuid?: string;
  enabled: boolean;
}

export const AdaptiveDialogueBridge: React.FC<AdaptiveDialogueBridgeProps> = ({
  activityAttemptGuid,
  enabled,
}) => {
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
      return;
    }

    window.dispatchEvent(
      new CustomEvent('oli:adaptive-screen-changed', {
        detail: { activityAttemptGuid },
      }),
    );
  }, [activityAttemptGuid, enabled]);

  return null;
};
