import { useEffect } from 'react';

export function useKeyDown(
  callback: (ctrlKey?: boolean, metaKey?: boolean, shiftKey?: boolean) => any,
  keyCodes: string[],
  options: { ctrlKey?: boolean; allowInEditable?: boolean } = {},
  dependencies: any = [],
): void {
  const handler = ({ metaKey, ctrlKey, shiftKey, code, target }: KeyboardEvent) => {
    const { ctrlKey: ctrlRequired, allowInEditable = false } = options;

    const targetElement = target as HTMLElement | null;
    const isEditableTarget =
      !!targetElement &&
      (targetElement.tagName === 'INPUT' ||
        targetElement.tagName === 'TEXTAREA' ||
        targetElement.tagName === 'SELECT' ||
        targetElement.isContentEditable ||
        targetElement.closest('[contenteditable="true"]') !== null);

    if (!allowInEditable && isEditableTarget) {
      return;
    }

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
