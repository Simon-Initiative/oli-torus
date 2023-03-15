import { AllPaths, AlwaysGoToPath, ComponentPath, OptionCommonErrorPath } from './path-types';

export const validatePath = (path: AllPaths) => {
  switch (path.type) {
    case 'end-of-activity':
      return true;

    case 'correct':
    case 'incorrect':
      return validateComponentRule(path);

    case 'always-go-to':
      return validateAlwaysGoTo(path);

    case 'option-common-error':
      return validateSelectedOption(path);

    case 'unknown-reason-path':
      return false;

    default:
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const _exhaustiveCheck: never = path; // Will throw type error if any rule type is not handled

      return false;
  }
};

const validateSelectedOption = (path: OptionCommonErrorPath) => {
  return validateComponentRule(path) && path.selectedOption !== null;
};

const validateAlwaysGoTo = (path: AlwaysGoToPath) => {
  return !!path.destinationScreenId;
};

const validateComponentRule = (path: ComponentPath) => {
  return !!(path.destinationScreenId && path.componentId);
};
