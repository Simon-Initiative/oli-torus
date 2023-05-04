import { INavigationAction } from '../../../../delivery/store/features/activities/slice';

// Provide a sequence id to go to
export const createNavigationAction = (target: string): INavigationAction => {
  return {
    type: 'navigation',
    params: {
      target,
    },
  };
};
