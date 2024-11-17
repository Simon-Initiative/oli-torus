import React, { useEffect, useRef } from 'react';
import { Mathfield, MathfieldElement, MathfieldOptions } from 'mathlive';
import 'mathlive/dist/mathlive-fonts.css';
import 'mathlive/dist/sounds/keypress-delete.wav';
import 'mathlive/dist/sounds/keypress-return.wav';
import 'mathlive/dist/sounds/keypress-spacebar.wav';
import 'mathlive/dist/sounds/keypress-standard.wav';
import 'mathlive/dist/sounds/plonk.wav';
import { classNames } from 'utils/classNames';
import { valueOr } from 'utils/common';
import styles from './MathLive.modules.scss';

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
  onKeyUp?: (e: React.KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
}

export const MathLive = ({
  className,
  options,
  value,
  initialValue,
  inline,
  onChange,
  onKeyUp,
}: MathLiveProps) => {
  const divRef = useRef<HTMLDivElement>(null);
  const mfe = useRef<MathfieldElement | null>(null);

  // state tracked to suppress unnecessary onChange notifications:
  const [lastNotifiedValue, setLastNotifiedValue] = React.useState<string | null>(null);

  // get effective options as string for useEffect dependency
  const mathFieldOptions = mergeOptions(DEFAULT_OPTIONS, valueOr(options, {}));
  const optionString = JSON.stringify(mathFieldOptions);

  useEffect(() => {
    // Setting this to large value ensures MathLive keyboard renders at top of z-order
    document.body.style.setProperty('--keyboard-zindex', '3000');

    // As a workaround to an issue where the MathfieldElement package must be using global state,
    // we must first check to see if it is already defined globally. If so, we use the class that
    // if defined on the window. Otherwise, use the class imported from the package. Ugh.
    if ((window as any).MathfieldElement) {
      mfe.current = new (window as any).MathfieldElement() as MathfieldElement;
    } else {
      mfe.current = new MathfieldElement() as MathfieldElement;
    }

    if (initialValue !== undefined) mfe.current.value = initialValue;

    divRef.current?.appendChild(mfe.current as any);

    // return value is cleanup function
    const mathfieldParent = divRef.current;
    return () => {
      if (mfe.current !== null) {
        mathfieldParent?.removeChild(mfe.current);
      }
    };

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // handle any prop change affecting options
  useEffect(() => {
    if (onChange !== undefined) {
      mathFieldOptions.onContentDidChange = (mf: Mathfield) => {
        // Found can get these when no change in value, causing problems
        const value = mf.getValue();
        if (value !== lastNotifiedValue) {
          onChange(value);
          setLastNotifiedValue(value);
        }
      };
    }

    if (onKeyUp !== undefined) {
      // Mathfield fires onCommit on hitting Enter OR losing focus w/change.
      // Just treat both as Enter keypress for purpose of auto-submitting
      mathFieldOptions.onCommit = (mf: Mathfield) => {
        onKeyUp({ key: 'Enter' } as React.KeyboardEvent<HTMLInputElement>);
      };
    }

    mfe.current?.setOptions(mathFieldOptions);
  }, [optionString, onChange, onKeyUp]);

  useEffect(() => {
    // firing onChange handler in middle of activity reset process led to errors
    // so suppress change notifications when programmatically setting value
    if (value !== undefined) {
      mfe.current?.setValue(value, { suppressChangeNotifications: true });
    }
  }, [value]);

  return (
    <div
      ref={divRef}
      className={classNames(
        styles.mathLive,
        className,
        options?.readOnly && styles.disabled,
        inline && styles.inline,
      )}
    ></div>
  );
};
