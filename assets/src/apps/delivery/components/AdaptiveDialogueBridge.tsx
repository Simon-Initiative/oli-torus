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
