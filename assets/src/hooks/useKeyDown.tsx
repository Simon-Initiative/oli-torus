import { useEffect } from 'react';

export function useKeyDown(
  callback: () => void,
  keyCodes: string[],
  options: { ctrlKey?: boolean; shiftKey?: boolean; metaKey?: boolean } = {},
  dependencies: any = [],
): void {
  const handler = ({ metaKey, ctrlKey, shiftKey, code }: KeyboardEvent) => {
    const { ctrlKey: ctrlRequired, shiftKey: shiftRequired, metaKey: metaRequired } = options;

    let ctrlMatch = ctrlRequired === undefined || ctrlKey === ctrlRequired;
    const metaMatch = metaKey === metaRequired;
    const shiftMatch = shiftKey === shiftRequired;

    if (!ctrlMatch && metaKey && shiftRequired === undefined) {
      ctrlMatch = metaKey === ctrlRequired;
    }
    if (((metaMatch && shiftMatch) || (ctrlMatch && !shiftKey)) && keyCodes.includes(code)) {
      callback();
    }
  };

  useEffect(() => {
    window.addEventListener('keydown', handler);
    return () => {
      window.removeEventListener('keydown', handler);
    };
  }, dependencies);
}
