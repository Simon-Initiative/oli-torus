import guid from '../../../../../utils/guid';
import { IAdaptiveRule } from '../../../../delivery/store/features/activities/slice';
import { AllPaths, AlwaysGoToPath } from '../paths/path-types';

// These handle compiling paths into rules.
export const generateDefaultRule = (path: AllPaths): IAdaptiveRule | null => {
  switch (path.type) {
    case 'end-of-activity':
      return null; // no real rule to generate
    // case 'correct':
    //   return generateMultipleChoiceCorrect(path);
    case 'always-go-to':
      return generateAlwaysGoTo(path);
    default:
      console.error('Unknown rule type', path.type);
      return null;
  }
};

const generateAlwaysGoTo = (path: AlwaysGoToPath): IAdaptiveRule => {
  const label = 'always';
  return {
    id: `r:${guid()}.${label}`,
    name: label,
    priority: 1,
    event: {
      type: `r:${guid()}.default`,
      params: {
        actions: [
          {
            type: 'navigation',
            params: {
              target: String(path.destinationScreenId),
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

// const generateMultipleChoiceCorrect = (path: MultipleChoiceCorrectPath): IAdaptiveRule => {
//   const label = 'correct';
//   return {
//     id: `r:${guid()}.${label}`,
//     name: 'correct',
//     event: {
//       type: `r:${guid()}.${label}`,
//       params: {
//         actions: [
//           {
//             type: 'navigation',
//             params: {
//               target: String(path.destinationScreenId),
//             },
//           },
//         ],
//       },
//     },
//     correct: true,
//     default: true,
//     disabled: false,
//     priority: 1,
//     conditions: {
//       id: `c:${guid()}`,
//       all: [
//         {
//           id: `c:${guid()}`,
//           fact: `stage.${path.componentId}.selectedChoice`,
//           type: 1,
//           value: String(path.correctOption),
//           operator: 'equal',
//         },
//       ],
//     },
//     forceProgress: false,
//     additionalScore: 0,
//   };
// };
