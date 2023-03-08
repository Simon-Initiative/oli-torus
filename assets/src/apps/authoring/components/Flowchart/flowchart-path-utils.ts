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
import guid from '../../../../utils/guid';
import { IActivity } from '../../../delivery/store/features/activities/slice';
import { FlowchartEdge } from './flowchart-utils';

export interface AuthoringFlowchartScreenData {
  paths: AllPaths[];
}

interface BasePath {
  type: string;
  id: string;
  ruleId: string | null;
  completed: boolean;
}
export interface DestinationPath extends BasePath {
  destinationScreenId: number | null;
}

export interface ComponentPath extends DestinationPath {
  componentId: string | null;
}

export interface MultipleChoiceCorrectPath extends ComponentPath {
  type: 'multiple-choice-correct';
  correctOption: number;
}

export interface MultipleChoiceIncorrectPath extends ComponentPath {
  type: 'multiple-choice-incorrect';
  correctOption: number;
}

export interface MultipleChoiceCommonErrorPath extends ComponentPath {
  type: 'multiple-choice-common-error';
  selectedOption: number;
}

export interface AlwaysGoToPath extends DestinationPath {
  type: 'always-go-to';
}

export interface EndOfActivityPath extends BasePath {
  type: 'end-of-activity';
}

// All our path types representing a "correct" answer
export const correctPathTypes = ['multiple-choice-correct'];

// Sometimes we do know where we want to go to, but we don't know why. This is a placeholder for that.
export interface UnknownPathWithDestination extends DestinationPath {
  type: 'unknown-reason-path';
}

export type DestinationPaths =
  | MultipleChoiceCorrectPath
  | MultipleChoiceIncorrectPath
  | MultipleChoiceCommonErrorPath
  | AlwaysGoToPath
  | UnknownPathWithDestination;

export type AllPaths = EndOfActivityPath | DestinationPaths;

export type RuleTypes = AllPaths['type'];

const getPathsFromScreen = (screen: IActivity): AllPaths[] => {
  if (!screen.authoring) {
    throw new Error('Can not modify screens without authoring data.');
  }
  if (!screen.authoring.flowchart) {
    // If there's no flowchart data, create it.
    screen.authoring.flowchart = {
      paths: [],
    };
  }

  const { paths } = screen.authoring.flowchart;
  return paths;
};

export const isEndOfActivityPath = (path: AllPaths): path is EndOfActivityPath =>
  path.type === 'end-of-activity';

export const isDestinationPath = (path: AllPaths): path is DestinationPaths =>
  'destinationScreenId' in path;

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
  return paths.filter(isDestinationPath).map(destinationPathToEdge(activity));
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

export const createUnknownPathWithDestination = (
  destinationScreenId: number,
): UnknownPathWithDestination => ({
  type: 'unknown-reason-path',
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: false,
});

export const createAlwaysGoToPath = (destinationScreenId: number): AlwaysGoToPath => ({
  type: 'always-go-to',
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: !!destinationScreenId,
});

export const createEndOfActivityPath = (): EndOfActivityPath => ({
  type: 'end-of-activity',
  id: guid(),
  ruleId: null,
  completed: false,
});

export const generateRule = (path: AllPaths) => {
  switch (path.type) {
    case 'end-of-activity':
      return null; // no real rule to generate
    case 'multiple-choice-correct':
      return generateMultipleChoiceCorrect(path);
    case 'always-go-to':
      return generateAlwaysGoTo(path);
    default:
      console.error('Unknown rule type', path.type);
      return {};
  }
};

export const validateRule = (path: AllPaths) => {
  switch (path.type) {
    case 'end-of-activity':
      return true;
    case 'multiple-choice-correct':
      return validateMultipleChoiceCorrect(path);
    case 'always-go-to':
      return validateAlwaysGoTo(path);
    default:
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      // const _exhaustiveCheck: never = rule; -- TODO - type checking
      console.error('Unknown rule type', path.type);
      return false;
  }
};

const validateAlwaysGoTo = (path: AlwaysGoToPath) => {
  return path.destinationScreenId;
};

const validateComponentRule = (path: ComponentPath) => {
  return path.destinationScreenId && path.componentId;
};

const validateMultipleChoiceCorrect = (path: MultipleChoiceCorrectPath) => {
  return validateComponentRule(path) && !isNaN(path.correctOption);
};

// TODO - types of these generated rules
const generateAlwaysGoTo = (path: AlwaysGoToPath) => {
  const label = 'always';
  return {
    id: `r:${guid()}.${label}`,
    name: label,
    event: {
      type: `r:${guid()}.default`,
      params: {
        actions: [
          {
            type: 'navigation',
            params: {
              target: path.destinationScreenId,
            },
          },
        ],
      },
    },
    correct: true,
    default: true,
    disabled: false,
    conditions: {
      id: `b:${guid()}`,
      all: [],
    },
    forceProgress: false,
    additionalScore: 0,
  };
};

const generateMultipleChoiceCorrect = (path: MultipleChoiceCorrectPath) => {
  const label = 'correct';
  return {
    id: `r:${guid()}.${label}`,
    name: 'correct',
    event: {
      type: `r:${guid()}.${label}`,
      params: {
        actions: [
          {
            type: 'navigation',
            params: {
              target: path.destinationScreenId,
            },
          },
        ],
      },
    },
    correct: true,
    default: true,
    disabled: false,
    priority: 1,
    conditions: {
      all: [
        {
          id: `c:${guid()}`,
          fact: `stage.${path.componentId}.selectedChoice`,
          type: 1,
          value: String(path.correctOption),
          operator: 'equal',
        },
      ],
    },
    forceProgress: false,
    additionalScore: 0,
  };
};

const isValidNumber = (n: number | undefined | null): n is number => typeof n === 'number';

export const getDownstreamScreenIds = (screen: IActivity): number[] =>
  screen.authoring?.flowchart?.paths
    .filter(isDestinationPath)
    .map((path) => path.destinationScreenId)
    .filter(isValidNumber) || [];
