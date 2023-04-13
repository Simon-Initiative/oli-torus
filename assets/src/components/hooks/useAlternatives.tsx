import React, { PropsWithChildren, useEffect, useState } from 'react';
import { AlternativesGroup } from 'data/persistence/resource';
import * as Persistence from 'data/persistence/resource';

export enum AlternativesTypes {
  REQUEST,
  SUCCESS,
  FAILURE,
}

type AlternativesState =
  | { type: AlternativesTypes.REQUEST }
  | {
      type: AlternativesTypes.SUCCESS;
      alternatives: AlternativesGroup[];
      alternativesOptionsTitles: Record<number, Record<string, string>>;
    }
  | { type: AlternativesTypes.FAILURE; error: string };

const AlternativesContext = React.createContext<AlternativesState | null>(null);

export const useAlternatives = (): AlternativesState => {
  const context = React.useContext(AlternativesContext);

  if (!context)
    throw new Error(
      '`useAlternatives` hook must be used inside an <AlternativesContext.Provider> context',
    );

  return context;
};

interface AlternativesContextProviderProps {
  projectSlug: string;
}

export const AlternativesContextProvider = ({
  projectSlug,
  children,
}: PropsWithChildren<AlternativesContextProviderProps>) => {
  const [alternativesState, setAlternativesState] = useState<AlternativesState>({
    type: AlternativesTypes.REQUEST,
  });

  useEffect(() => {
    Persistence.alternatives(projectSlug)
      .then((result) => {
        if (result.type === 'success') {
          const alternativesOptionsTitles = result.alternatives.reduce(
            (acc, group) => ({
              ...acc,
              [group.id]: group.options.reduce(
                (acc, options) => ({ ...acc, [options.id]: options.name }),
                {} as Record<string, string>,
              ),
            }),
            {} as Record<number, Record<string, string>>,
          );

          setAlternativesState({
            type: AlternativesTypes.SUCCESS,
            alternatives: result.alternatives,
            alternativesOptionsTitles,
          });
        } else {
          setAlternativesState({
            type: AlternativesTypes.FAILURE,
            error: result.message,
          });
        }
      })
      .catch(({ message }) =>
        setAlternativesState({
          type: AlternativesTypes.FAILURE,
          error: message,
        }),
      );
  }, []);

  return (
    <AlternativesContext.Provider value={alternativesState}>
      {children}
    </AlternativesContext.Provider>
  );
};
