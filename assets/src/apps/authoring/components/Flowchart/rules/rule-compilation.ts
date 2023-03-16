import guid from '../../../../../utils/guid';
import { IAdaptiveRule } from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { AllPaths, AlwaysGoToPath } from '../paths/path-types';
import { createNavigationAction } from './create-navigation-action';

export const generateRules = (
  paths: AllPaths[],
  sequence: SequenceEntry<SequenceEntryChild>[],
): IAdaptiveRule[] => {
  return paths.map(generateRule(sequence)).flat();
};
// These handle compiling paths into rules.
const generateRule =
  (sequence: SequenceEntry<SequenceEntryChild>[]) =>
  (path: AllPaths): IAdaptiveRule[] => {
    switch (path.type) {
      case 'end-of-activity':
        return []; // no real rule to generate
      // case 'correct':
      //   return generateMultipleChoiceCorrect(path);
      case 'always-go-to':
        return generateAlwaysGoTo(path, sequence);
      default:
        console.error('Unknown rule type', path.type);
        return [];
    }
  };

const createRuleTemplate = (label: string): IAdaptiveRule => {
  return {
    id: `r:${guid()}.${label}`,
    name: label,
    priority: 1,
    event: {
      type: `r:${guid()}.default`,
      params: {
        actions: [],
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

const generateAlwaysGoTo = (
  path: AlwaysGoToPath,
  sequence: SequenceEntry<SequenceEntryChild>[],
): IAdaptiveRule[] => {
  const rule = createRuleTemplate('always');
  const sequenceEntry = sequence.find((s) => s.resourceId === path.destinationScreenId);
  if (!sequenceEntry) {
    console.warn("Couldn't find sequence entry for path", path);
    return [];
  }
  rule.event.params.actions = [createNavigationAction(sequenceEntry.custom.sequenceId)];
  return [rule];
};
