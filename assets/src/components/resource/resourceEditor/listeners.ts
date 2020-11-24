import { PersistenceStrategy } from 'data/persistence/PersistenceStrategy';
import { isFirefox } from 'utils/browser';
import { toKeyCode } from 'is-hotkey';
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

export function registerKeydown(self: ResourceEditor) {
  return window.addEventListener('keydown', (e: KeyboardEvent) => {
    if (e.keyCode === toKeyCode('mod') && !e.repeat) {
      self.setState({ metaModifier: true });
    }
  });
}

export function unregisterKeydown(listener: any) {
  window.removeEventListener('keydown', listener);
}

export function registerKeyup(self: ResourceEditor) {
  return window.addEventListener('keyup', (e: KeyboardEvent) => {
    if (e.keyCode === toKeyCode('mod')) {
      self.setState({ metaModifier: false });
    }
  });
}

export function unregisterKeyup(listener: any) {
  window.removeEventListener('keyup', listener);
}

export function registerWindowBlur(self: ResourceEditor) {
  return window.addEventListener('blur', (e) => {
    self.setState({ metaModifier: false });
  });
}

export function unregisterWindowBlur(listener: any) {
  window.removeEventListener('blur', listener);
}
