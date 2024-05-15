import { useEffect } from 'react';

export function useKeyDown(callback: () => void, keyCodes: string[], dependencies: any = []): void {
  const handler = ({ metaKey, ctrlKey, code }: KeyboardEvent) => {
    // event.metaKey - pressed Command key on  Macs
    // event.ctrlKey - pressed Control key on Linux or Windows
    if (metaKey || ctrlKey || code === 'Delete' || code === 'Backspace') {
      if (keyCodes.includes(code)) {
        callback();
      }
    }
  };

  useEffect(() => {
    window.addEventListener('keydown', handler);
    return () => {
      window.removeEventListener('keydown', handler);
    };
  }, dependencies);
}
