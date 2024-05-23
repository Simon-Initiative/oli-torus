import { useEffect } from 'react';

export function useKeyDown(
  callback: () => void,
  keyCodes: string[],
  options: { ctrlKey?: boolean } = {},
  dependencies: any = [],
): void {
  const handler = ({ metaKey, ctrlKey, code }: KeyboardEvent) => {
    const { ctrlKey: ctrlRequired } = options;

    const ctrlMatch =
      ctrlRequired === undefined || ctrlKey === ctrlRequired || metaKey === ctrlRequired;
    if (ctrlMatch && keyCodes.includes(code)) {
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
