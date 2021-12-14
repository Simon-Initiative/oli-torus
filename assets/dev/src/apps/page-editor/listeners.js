import { isFirefox } from 'utils/browser';
export function registerUnload(strategy) {
    return window.addEventListener('beforeunload', (event) => {
        if (isFirefox) {
            setTimeout(() => strategy.destroy());
        }
        else {
            strategy.destroy();
        }
    });
}
export function unregisterUnload(listener) {
    window.removeEventListener('beforeunload', listener);
}
export function unregisterKeydown(listener) {
    window.removeEventListener('keydown', listener);
}
export function unregisterKeyup(listener) {
    window.removeEventListener('keyup', listener);
}
export function unregisterWindowBlur(listener) {
    window.removeEventListener('blur', listener);
}
//# sourceMappingURL=listeners.js.map