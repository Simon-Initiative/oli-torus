import { IActivity } from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { isDestinationPath } from '../paths/path-utils';

export const sortScreens = (
  screens: IActivity[],
  sequence: SequenceEntry<SequenceEntryChild>[],
): IActivity[] => {
  const firstActivity = sequence.find((c) => !!c.resourceId);
  const firstScreen = screens.find((s) => s.resourceId === firstActivity?.resourceId);
  const screensLeft = screens.filter((s) => s.resourceId !== firstScreen?.resourceId);

  if (!firstScreen) return screens;

  const sortedScreens = [firstScreen, ...getOrderedPath(firstScreen, screensLeft)];

  const unlinkedScreens = screens.filter((s) => !sortedScreens.includes(s));
  const pathSorted = [...sortedScreens, ...unlinkedScreens];

  // Make sure the welcome screen is first and the end screen is last.
  // Because we're sorting depth-first, the end screen is often before some alternate branches.
  const welcomeScreen = pathSorted.find(isWelcomeScreen);
  if (welcomeScreen) {
    const welcomeScreenIndex = pathSorted.indexOf(welcomeScreen);
    if (welcomeScreenIndex > 0) {
      pathSorted.splice(welcomeScreenIndex, 1);
      pathSorted.unshift(welcomeScreen);
    }
  }

  const endScreen = pathSorted.find(isEndScreen);
  if (endScreen) {
    const endScreenIndex = pathSorted.indexOf(endScreen);
    if (endScreenIndex < pathSorted.length - 1) {
      pathSorted.splice(endScreenIndex, 1);
      pathSorted.push(endScreen);
    }
  }

  return pathSorted;
};

const isWelcomeScreen = (screen: IActivity): boolean =>
  screen.authoring?.flowchart?.screenType === 'welcome_screen';

const isEndScreen = (screen: IActivity): boolean =>
  screen.authoring?.flowchart?.screenType === 'end_screen';

const isScreen = (screen: IActivity | undefined): screen is IActivity => !!screen;

const getOrderedPath = (screen: IActivity, screensLeft: IActivity[]): IActivity[] => {
  const paths = screen.authoring?.flowchart?.paths || [];

  const destinationPaths = paths.filter(isDestinationPath);

  const nextScreens = destinationPaths
    .map((p) => screensLeft.find((s) => s.resourceId === p.destinationScreenId))
    .filter(isScreen);

  for (const nextScreen of nextScreens) {
    const remainingScreens = screensLeft.filter((s) => !nextScreens.includes(s));
    const nextBranch = getOrderedPath(nextScreen, remainingScreens);
    nextScreens.push(...nextBranch);
  }

  return nextScreens;
};
