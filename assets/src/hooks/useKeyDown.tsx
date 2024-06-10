import { useEffect } from 'react';

export function useKeyDown(
  callback: (ctrlKey?: boolean, metaKey?: boolean, shiftKey?: boolean) => any,
  keyCodes: string[],
  options: { ctrlKey?: boolean } = {},
  dependencies: any = [],
): void {
  const handler = ({ metaKey, ctrlKey, shiftKey, code }: KeyboardEvent) => {
    const { ctrlKey: ctrlRequired } = options;

    const ctrlMatch =
      ctrlRequired === undefined || ctrlKey === ctrlRequired || metaKey === ctrlRequired;
    if (ctrlMatch && keyCodes.includes(code)) {
      callback(ctrlKey, metaKey, shiftKey);
    }
  };

  useEffect(() => {
    window.addEventListener('keydown', handler);
    return () => {
      window.removeEventListener('keydown', handler);
    };
  }, dependencies);
}
