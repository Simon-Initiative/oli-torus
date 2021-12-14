import React from 'react';
export const NotificationContext = React.createContext(null);
export var NotificationType;
(function (NotificationType) {
    NotificationType["CHECK_STARTED"] = "checkStarted";
    NotificationType["CHECK_COMPLETE"] = "checkComplete";
    NotificationType["STATE_CHANGED"] = "stateChanged";
    NotificationType["CONTEXT_CHANGED"] = "contextChanged";
    NotificationType["CONFIGURE"] = "configure";
    NotificationType["CONFIGURE_SAVE"] = "configureSave";
    NotificationType["CONFIGURE_CANCEL"] = "configureCancel";
})(NotificationType || (NotificationType = {}));
export const subscribeToNotification = (emitter, notification, listener) => {
    emitter.on(notification.toString(), listener);
    return () => {
        emitter.off(notification.toString(), listener);
    };
};
//# sourceMappingURL=NotificationContext.jsx.map