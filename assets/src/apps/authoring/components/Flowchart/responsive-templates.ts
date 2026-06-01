import {
  INTERACTIVE_SCREEN_TYPES,
  buildInteractiveTemplatesForType,
  instructionalTemplates,
} from './responsive-template-builders';

export const responsiveTemplates = [
  ...INTERACTIVE_SCREEN_TYPES.flatMap((screenType) => buildInteractiveTemplatesForType(screenType)),
  ...instructionalTemplates,
];
