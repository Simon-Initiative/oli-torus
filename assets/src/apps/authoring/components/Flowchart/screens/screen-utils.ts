import uniq from 'lodash/uniq';
import { IActivity } from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { isDestinationPath } from '../paths/path-utils';

export const getFirstScreenInSequence = (
  screens: IActivity[],
  sequence: SequenceEntry<SequenceEntryChild>[],
): IActivity | undefined => {
  const firstScreenId = sequence[0]?.resourceId;
  return screens.find((s) => s.resourceId === firstScreenId);
};

export const sortScreens = (screens: IActivity[], firstScreen?: IActivity): IActivity[] => {
  const sortedByTitle: IActivity[] = screens.sort((a, b) => {
    if (!a.title || !b.title) return 0;
    return a.title.localeCompare(b.title);
  });

  const screensLeft = sortedByTitle.filter((s) => s.resourceId !== firstScreen?.resourceId);

  if (!firstScreen) return sortedByTitle;

  const sortedScreens = [firstScreen, ...getOrderedPath(firstScreen, screensLeft)];

  const unlinkedScreens = sortedByTitle.filter((s) => !sortedScreens.includes(s));
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

export const isEndScreen = (screen: IActivity): boolean =>
  screen.authoring?.flowchart?.screenType === 'end_screen';

const isScreen = (screen: IActivity | undefined): screen is IActivity => !!screen;

export function getOrderedPath(screen: IActivity, screensLeft: IActivity[]): IActivity[] {
  const paths = screen.authoring?.flowchart?.paths || [];

  const destinationPaths = paths.filter(isDestinationPath);

  const nextScreens = uniq(
    destinationPaths
      .map((p) => screensLeft.find((s) => s.resourceId === p.destinationScreenId))
      .filter(isScreen),
  );

  for (const nextScreen of nextScreens) {
    const remainingScreens = screensLeft.filter((s) => !nextScreens.includes(s));
    const nextBranch = getOrderedPath(nextScreen, remainingScreens);
    nextScreens.push(...nextBranch);
  }

  return nextScreens;
}
