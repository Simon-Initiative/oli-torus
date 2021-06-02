import { EventEmitter } from 'events';
import React from 'react';

export const NotificationContext = React.createContext<EventEmitter | null>(null);

export enum NotificationType {
  CHECK_STARTED = 'checkStarted',
  CHECK_COMPLETE = 'checkComplete',
  STATE_CHANGED = 'stateChanged',
  CONTEXT_CHANGED = 'contextChanged',
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
