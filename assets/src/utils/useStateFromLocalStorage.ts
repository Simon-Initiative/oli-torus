import { useState } from 'react';
import { fromJS, isImmutable } from 'immutable';

const maybeHydrateImmutable = (maybeImmutable: any) =>
  maybeImmutable instanceof Object && maybeImmutable.isImmutable
    ? fromJS(maybeImmutable.value)
    : maybeImmutable;

export const useStateFromLocalStorage = <S>(
  initialState: S | (() => S),
  localStorageKey: string,
) => {
  const localStorageState = localStorage.getItem(localStorageKey);
  const loadedState =
    localStorageState !== null
      ? maybeHydrateImmutable(JSON.parse(localStorageState))
      : initialState;

  const [state, setState] = useState(loadedState);

  return [
    state,
    (value: S) => {
      if (isImmutable(value)) {
        localStorage.setItem(
          localStorageKey,
          JSON.stringify({ isImmutable: true, value: value.toJS() }),
        );
      } else {
        localStorage.setItem(localStorageKey, JSON.stringify(value));
      }

      setState(value);
    },
  ];
};
