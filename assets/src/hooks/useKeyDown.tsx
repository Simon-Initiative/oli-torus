import { useEffect } from 'react';

export function useKeyDown(
  callback: () => void,
  keyCodes: string[],
  options: { ctrlKey?: boolean; shiftKey?: boolean } = {},
  dependencies: any = [],
): void {
  const handler = ({ metaKey, ctrlKey, shiftKey, code }: KeyboardEvent) => {
    const { ctrlKey: ctrlRequired, shiftKey: shiftRequired } = options;

    const ctrlMatch =
      ctrlRequired === undefined || ctrlKey === ctrlRequired || metaKey === ctrlRequired;
    const shiftMatch = shiftRequired === undefined || shiftKey === shiftRequired;
    if (ctrlMatch && shiftMatch && keyCodes.includes(code)) {
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
