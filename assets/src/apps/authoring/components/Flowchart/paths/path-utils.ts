/*
  The Flowchart component has paths between screens.
  A path might not be fully defined. For instance, it might not tell us what screen it goes to.
  Before it's fully defined, the ruleId is null.  When that path is defined well enough, it can be compiled into a rule that the adaptive engine uses.

  This path isn't "valid" until it has a ruleId.
  If the path is deleted, we should delete the corresponding rule.
  If the path is edited, we should update the corresponding rule.

  Question:
    Do we want to just re-generate all the rules every save, or try to update & delete them?

*/

import { MarkerType } from 'reactflow';
import {
  IActivity,
  IDropdownPartLayout,
  IMCQPartLayout,
  IPartLayout,
} from '../../../../delivery/store/features/activities/slice';
import { FlowchartEdge } from '../flowchart-utils';
import { createAlwaysGoToPath, createUnknownPathWithDestination } from './path-factories';
import {
  AllPaths,
  AlwaysGoToPath,
  ComponentPaths,
  componentTypes,
  DestinationPath,
  DestinationPaths,
  EndOfActivityPath,
  OptionCommonErrorPath,
} from './path-types';

const getPathsFromScreen = (screen: IActivity): AllPaths[] => {
  if (!screen.authoring) {
    throw new Error('Can not modify screens without authoring data.');
  }
  if (!screen.authoring.flowchart) {
    // If there's no flowchart data, create it.
    screen.authoring.flowchart = {
      paths: [],
      screenType: 'blank_screen',
      templateApplied: false,
    };
  }

  const { paths } = screen.authoring.flowchart;
  return paths;
};

export const isComponentPath = (path: AllPaths): path is ComponentPaths =>
  componentTypes.includes(path.type);

export const isMCQ = (screen: IPartLayout): screen is IMCQPartLayout => screen.type === 'janus-mcq';
export const isDropdown = (screen: IPartLayout): screen is IDropdownPartLayout =>
  screen.type === 'janus-dropdown';

export const isEndOfActivityPath = (path: AllPaths): path is EndOfActivityPath =>
  path.type === 'end-of-activity';

export const isDestinationPath = (path: AllPaths): path is DestinationPaths =>
  'destinationScreenId' in path;

export const isOptionCommonErrorPath = (path: AllPaths): path is OptionCommonErrorPath =>
  path.type === 'option-common-error';

export const hasDestination = (path: DestinationPath): path is DestinationPaths =>
  !!path.destinationScreenId;

export const missingDestination = (path: DestinationPath): path is DestinationPaths =>
  !path.destinationScreenId;

const destinationPathToEdge = (activity: IActivity) => (path: DestinationPath) => ({
  id: String(path.id),
  source: String(activity.id),
  target: String(path.destinationScreenId),
  type: 'floating',
  data: {
    completed: path.completed,
  },
  markerEnd: {
    type: MarkerType.Arrow,
    color: '#22f',
  },
});

export const buildEdgesForActivity = (activity: IActivity): FlowchartEdge[] => {
  const paths = getPathsFromScreen(activity);
  return paths
    .filter(isDestinationPath)
    .filter(hasDestination)
    .map(destinationPathToEdge(activity));
};

export const removeEndOfActivityPath = (screen: IActivity) => {
  const paths = getPathsFromScreen(screen);

  // getPathsFromScreen makes sure .authoring.flowchart.paths exists.
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  screen.authoring!.flowchart!.paths = paths.filter((path) => path.type !== 'end-of-activity');
};

// If this screen doesn't already point to the destination somehow, add a new path of the UnknownPathWithDestination type
export const setUnknownPathDestination = (screen: IActivity, destinationScreenId: number) => {
  const paths = getPathsFromScreen(screen);
  if (
    paths.filter(isDestinationPath).some((path) => path.destinationScreenId === destinationScreenId)
  ) {
    // Already have a path going there
    return;
  }
  paths.push(createUnknownPathWithDestination(destinationScreenId));
};

export const hasDestinationPath = (screen: IActivity) => {
  const paths = getPathsFromScreen(screen);
  return paths.some(isDestinationPath);
};

// If this screen points to destination, remove that path
export const removeDestinationPath = (screen: IActivity, destinationScreenId: number) => {
  const paths = getPathsFromScreen(screen);
  screen.authoring!.flowchart!.paths = paths.filter(
    (p) => !('destinationScreenId' in p) || p.destinationScreenId !== destinationScreenId,
  );
};

export const setGoToAlwaysPath = (screen: IActivity, destinationScreenId: number) => {
  const paths = getPathsFromScreen(screen);
  // If there's already a go-to-always path, update it.
  // If not, add a new one.
  // Remove any end-of-activity paths since we now have a path out.
  const existingPath = paths.find((path) => path.type === 'always-go-to') as AlwaysGoToPath;
  if (existingPath) {
    existingPath.destinationScreenId = destinationScreenId;
  } else {
    paths.push(createAlwaysGoToPath(destinationScreenId));
  }
  removeEndOfActivityPath(screen);
};

const isValidNumber = (n: number | undefined | null): n is number => typeof n === 'number';

export const getDownstreamScreenIds = (screen: IActivity): number[] =>
  screen.authoring?.flowchart?.paths
    .filter(isDestinationPath)
    .map((path: DestinationPaths) => path.destinationScreenId)
    .filter(isValidNumber) || [];

// Adds a componentId attribute, if the path should have one.
export const addComponentId = (path: AllPaths, componentId: string | null): AllPaths => {
  if (!componentId) return path;
  if (!isComponentPath(path)) return path;
  return {
    ...path,
    componentId,
  };
};

// Adds a destinationId attribute, if the path should have one.
export const addDestinationId = (path: AllPaths, destinationScreenId: number | null): AllPaths => {
  if (!destinationScreenId) return path;
  if (!isDestinationPath(path)) return path;
  return {
    ...path,
    destinationScreenId,
  };
};

export const sortByPriority = (a: AllPaths, b: AllPaths) => {
  return a.priority - b.priority;
};
