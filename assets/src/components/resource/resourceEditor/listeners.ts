import { PersistenceStrategy } from 'data/persistence/PersistenceStrategy';
import { isFirefox } from 'utils/browser';
import isHotkey from 'is-hotkey';
import { ResourceEditor } from './ResourceEditor';

export function registerUnload(strategy: PersistenceStrategy) {
  return window.addEventListener('beforeunload', (event) => {
    if (isFirefox) {
      setTimeout(() => strategy.destroy());
    } else {
      strategy.destroy();
    }
  });
}

export function unregisterUnload(listener: any) {
  window.removeEventListener('beforeunload', listener);
}

export function unregisterKeydown(listener: any) {
  window.removeEventListener('keydown', listener);
}

export function unregisterKeyup(listener: any) {
  window.removeEventListener('keyup', listener);
}

export function unregisterWindowBlur(listener: any) {
  window.removeEventListener('blur', listener);
}
