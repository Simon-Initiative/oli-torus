import styles from './MathLive.modules.scss';
import { Mathfield, MathfieldElement, MathfieldOptions } from 'mathlive';
import 'mathlive/dist/mathlive-fonts.css';
import 'mathlive/dist/sounds/keypress-delete.wav';
import 'mathlive/dist/sounds/keypress-return.wav';
import 'mathlive/dist/sounds/keypress-spacebar.wav';
import 'mathlive/dist/sounds/keypress-standard.wav';
import 'mathlive/dist/sounds/plonk.wav';
import React, { useEffect, useRef } from 'react';
import { classNames } from 'utils/classNames';
import { valueOr } from 'utils/common';

const DEFAULT_OPTIONS: Partial<MathfieldOptions> = {
  virtualKeyboardMode: 'manual',
  defaultMode: 'math',
};

const mergeOptions = (...options: Partial<MathfieldOptions>[]): Partial<MathfieldOptions> =>
  options.reduce((acc, o) => Object.assign(acc, o), {});

export interface MathLiveProps {
  className?: string;
  options?: Partial<MathfieldOptions>;
  // value is a LaTex string which is controlled by the parent component
  value?: string;
  // initialValue is a LaTex string which is first displayed when the component renders
  initialValue?: string;
  inline?: boolean;
  onChange?: (value: string) => void;
}

export const MathLive = ({
  className,
  options,
  value,
  initialValue,
  inline,
  onChange,
}: MathLiveProps) => {
  const ref = useRef<HTMLDivElement>(null);
  const mfe = useRef<MathfieldElement | null>(null);

  useEffect(() => {
    // As a workaround to an issue where the MathfieldElement package must be using global state,
    // we must first check to see if it is already defined globally. If so, we use the class that
    // if defined on the window. Otherwise, use the class imported from the package. Ugh.
    if ((window as any).MathfieldElement) {
      mfe.current = new (window as any).MathfieldElement() as MathfieldElement;
    } else {
      mfe.current = new MathfieldElement() as MathfieldElement;
    }

    mfe.current.value = initialValue ?? value ?? '';

    const mathFieldOptions = mergeOptions(DEFAULT_OPTIONS, valueOr(options, {}));
    if (onChange !== undefined) {
      mathFieldOptions.onContentDidChange = (mf: Mathfield) => onChange(mf.getValue());
    }

    mfe.current.setOptions(mathFieldOptions);

    ref.current?.appendChild(mfe.current as any);

    const mathLiveRef = ref.current;

    return () => {
      if (mfe.current !== null) {
        mathLiveRef?.removeChild(mfe.current);
      }
    };

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    mfe.current?.setValue(value);
  }, [value]);

  useEffect(() => {
    mfe.current?.setOptions(valueOr(options, {}));
  }, [options]);

  return (
    <div
      ref={ref}
      className={classNames(
        styles.mathLive,
        className,
        options?.readOnly && styles.disabled,
        inline && styles.inline,
      )}
    ></div>
  );
};
