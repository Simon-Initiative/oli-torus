import {
  selectActivityById,
  selectAllActivities,
} from '../../../delivery/store/features/activities/slice';
import { AuthoringRootState } from '../../store/rootReducer';
import {
  AllPaths,
  AlwaysGoToPath,
  correctPathTypes,
  DestinationPath,
  DestinationPaths,
} from './flowchart-path-utils';

// Returns a list of output paths for a screen.
export const selectScreenPaths = (state: AuthoringRootState, screenId: number): AllPaths[] => {
  const screenActivity = selectActivityById(state, screenId);
  return screenActivity?.authoring?.flowchart?.paths || [];
};

interface PathWithSource {
  path: AllPaths;
  sourceScreenId: number;
}

const pathToPathWithSource =
  (sourceScreenId: number) =>
  (path: AllPaths): PathWithSource => ({ path, sourceScreenId });

const filterDestination = (screenId: number) => (path: AllPaths) =>
  'destinationScreenId' in path && path.destinationScreenId === screenId;

// Return a list of input paths for a screen with what screen those come from.
export const selectPathsToScreen = (
  state: AuthoringRootState,
  screenId: number,
): PathWithSource[] => {
  const activities = selectAllActivities(state);
  return activities
    .filter((a) => !!a.resourceId)
    .map((a) => {
      const activityPaths = a.authoring?.flowchart?.paths || [];
      // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
      return activityPaths
        .filter(filterDestination(screenId))
        .map(pathToPathWithSource(a.resourceId!));
    })
    .flat();
};

const isAlwaysPath = (path: AllPaths): path is AlwaysGoToPath => path.type === 'always-go-to';
const isCorrectPath = (path: AllPaths): path is DestinationPaths =>
  correctPathTypes.indexOf(path.type) !== -1;
const isDestinationPath = (path: AllPaths): path is DestinationPaths => 'destinationId' in path;

// Return a good "default" screen to go to from this one based on paths set up.
// Priority:
//   #1 an always-go-to rule
//   #2 a "correct" rule
//   #3 the first rule we have with a destination id
//  Otherwise null
export const selectDefaultDestination = (
  rootState: AuthoringRootState,
  screenId: number,
): number | null => {
  const paths = selectScreenPaths(rootState, screenId);
  const always = paths.find(isAlwaysPath);
  if (always) return always.destinationScreenId;
  const correct = paths.find(isCorrectPath);
  if (correct) return correct.destinationScreenId;
  const destination = paths.find(isDestinationPath);
  if (destination) return destination.destinationScreenId;
  return null;
};
