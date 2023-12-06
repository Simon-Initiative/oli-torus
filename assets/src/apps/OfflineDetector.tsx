import React from 'react';
import { useOffline } from 'components/hooks/useOffline';
import { Alert } from 'components/misc/Alert';

export const OfflineDetector: React.FC = () => {
  const offline = useOffline();
  if (!offline) return null;

  return (
    <div className="fixed left-2 top-2 z-50">
      <Alert variant="warning">You have gone offline, your work will not be saved.</Alert>
    </div>
  );
};
