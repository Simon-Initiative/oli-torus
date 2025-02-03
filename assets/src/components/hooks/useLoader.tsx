import { useEffect, useState } from 'react';

export enum LoaderStatus {
  LOADING,
  SUCCESS,
  FAILURE,
}

export type Loader<T> =
  | { status: LoaderStatus.LOADING }
  | {
      status: LoaderStatus.SUCCESS;
      result: T;
    }
  | { status: LoaderStatus.FAILURE; error: string };


/**
 * Custom hook that loads data using persistence and returns the current state of the loader.
 *
 * @param load Function that loads data and returns a persistence result of type Ok<T> or ServerError
 * @returns Loader<T> that represents one of three states: LOADING, SUCCESS, FAILURE
 */
export const useLoader = <T,>(load: () => Promise<T>): [Loader<T>, reload: () => void] => {
  const [loader, setLoader] = useState<Loader<T>>({
    status: LoaderStatus.LOADING,
  });

  const reload = () => {
    setLoader({
      status: LoaderStatus.LOADING,
    });

    load()
      .then((result) => {
          setLoader({
            status: LoaderStatus.SUCCESS,
            result,
          });
      })
      .catch(({ message }) =>
        setLoader({
          status: LoaderStatus.FAILURE,
          error: message,
        }),
      );
  };

  // Load data on initial mount. Any subsequent reloads are triggered by the calling the reload function
  useEffect(() => reload(), []);

  return [loader, reload];
};
