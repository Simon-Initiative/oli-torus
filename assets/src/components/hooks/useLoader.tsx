import { useEffect, useState } from 'react';

enum LoaderStatus {
  LOADING,
  SUCCESS,
  FAILURE,
}

export type LoaderState<T> =
  | { status: LoaderStatus.LOADING }
  | {
      status: LoaderStatus.SUCCESS;
      result: T;
    }
  | { status: LoaderStatus.FAILURE; error: string };

type StateCallbacks<T, R> = {
  loading: () => R;
  success: (result: T) => R;
  failure: (error: string) => R;
};

export type Loader<T> = {
  state: LoaderState<T>;
  reload: () => void;
  caseOf: <R>(callbacks: StateCallbacks<T, R>) => R;
};

/**
 * Custom hook that loads data using persistence and returns the current state of the loader.
 *
 * @param load Function that loads data and returns a promise
 * @returns Loader<T> loader that can execute any of the three state callbacks, access the current state, and reload the data
 */
export const useLoader = <T,>(
  load: () => Promise<T>,
  deps: React.DependencyList = [],
): Loader<T> => {
  const [loader, setLoader] = useState<LoaderState<T>>({
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
  useEffect(() => reload(), deps);

  return {
    state: loader,
    reload: reload,
    caseOf: ({ loading, success, failure }) => {
      switch (loader.status) {
        case LoaderStatus.LOADING:
          return loading();
        case LoaderStatus.SUCCESS:
          return success(loader.result);
        case LoaderStatus.FAILURE:
          return failure(loader.error);
      }
    },
  };
};
