import { useEffect } from 'react';

export function useKeyDown(
  callback: () => void,
  keyCodes: string[],
  options: { ctrlKey?: boolean; metaKey?: boolean } = {},
  dependencies: any = [],
): void {
  const handler = ({ metaKey, ctrlKey, code }: KeyboardEvent) => {
    const { ctrlKey: ctrlRequired, metaKey: metaRequired } = options;

    const ctrlMatch = ctrlRequired === undefined || ctrlKey === ctrlRequired;
    const metaMatch = metaRequired === undefined || metaKey === metaRequired;
    console.log({ metaKey, ctrlKey, code, keyCodes });
    if (ctrlMatch && metaMatch && keyCodes.includes(code)) {
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
