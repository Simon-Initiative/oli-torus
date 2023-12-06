import { useEffect, useState } from 'react';

export const useOffline = () => {
  const [offline, setOffline] = useState(!navigator.onLine);

  useEffect(() => {
    const handleOffline = () => setOffline(true);
    const handleOnline = () => setOffline(false);
    window.addEventListener('offline', handleOffline);
    window.addEventListener('online', handleOnline);
    return () => {
      window.removeEventListener('offline', handleOffline);
      window.removeEventListener('online', handleOnline);
    };
  }, []);

  return offline;
};
