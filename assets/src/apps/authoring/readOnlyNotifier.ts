const DEFAULT_MESSAGE =
  'This page is in read-only mode. Toggle "Read only" off in the header to edit.';
const NOTIFICATION_THROTTLE_MS = 4000;

let lastNotificationAt = 0;

export const notifyReadOnlyEditBlocked = (message = DEFAULT_MESSAGE) => {
  if (typeof window === 'undefined') {
    return;
  }

  const now = Date.now();
  if (now - lastNotificationAt < NOTIFICATION_THROTTLE_MS) {
    return;
  }

  lastNotificationAt = now;
  (window as any).ReactToLiveView?.pushEvent('authoring_readonly_edit_blocked', { message });
};

export const resetReadOnlyEditBlockedNotification = () => {
  lastNotificationAt = 0;
};
