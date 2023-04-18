import React from 'react';
import { EventEmitter } from 'events';

export const NotificationContext = React.createContext<EventEmitter | null>(null);

export enum NotificationType {
  CHECK_STARTED = 'checkStarted',
  CHECK_COMPLETE = 'checkComplete',
  STATE_CHANGED = 'stateChanged',
  CONTEXT_CHANGED = 'contextChanged',
  CONFIGURE = 'configure',
  CONFIGURE_SAVE = 'configureSave',
  CONFIGURE_CANCEL = 'configureCancel',
}

type UnsubscribeFn = () => void;

export const subscribeToNotification = (
  emitter: EventEmitter,
  notification: NotificationType,
  listener: any,
): UnsubscribeFn => {
  emitter.on(notification.toString(), listener);
  return () => {
    emitter.off(notification.toString(), listener);
  };
};
