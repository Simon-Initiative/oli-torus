import {
  AllPaths,
  AlwaysGoToPath,
  ComponentPath,
  DropdownCommonErrorPath,
  MultipleChoiceCorrectPath,
} from './path-types';

export const validatePath = (path: AllPaths) => {
  switch (path.type) {
    case 'end-of-activity':
      return true;

    case 'dropdown-correct':
    case 'dropdown-incorrect':
    case 'multiple-choice-incorrect':
    case 'multiple-choice-correct':
      return validateComponentRule(path);

    case 'always-go-to':
      return validateAlwaysGoTo(path);

    case 'dropdown-common-error':
      return validateSelectedOption(path);

    default:
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      // const _exhaustiveCheck: never = rule; -- TODO - type checking
      console.error('Unknown rule type', path.type);
      return false;
  }
};

const validateSelectedOption = (path: DropdownCommonErrorPath) => {
  return validateComponentRule(path) && path.selectedOption !== null;
};

const validateAlwaysGoTo = (path: AlwaysGoToPath) => {
  return !!path.destinationScreenId;
};

const validateComponentRule = (path: ComponentPath) => {
  return !!(path.destinationScreenId && path.componentId);
};
