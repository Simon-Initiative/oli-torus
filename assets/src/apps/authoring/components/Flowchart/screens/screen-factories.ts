import {
  IActivityTemplate,
  createActivityTemplate,
} from '../../../store/activities/templates/activity';

export const screenTypes = [
  'blank_screen',
  'welcome_screen',
  'multiple_choice',
  'multiline_text',
  'slider',
  'hub_spoke',
  'end_screen',
  'number_input',
  'text_input',
  'dropdown',
];

export const screenType = {
  BLANK_SCREEN: 'blank_screen',
  WELCOME_SCREEN: 'welcome_screen',
  MULTIPLE_CHOICE_SCREEN: 'multiple_choice',
  MULTILINE_SCREEN: 'multiline_text',
  SLIDER_SCREEN: 'slider',
  HUB_SPOKE_SCREEN: 'hub_spoke',
  END_SCREEN: 'end_screen',
  NUMBER_INPUT_SCREEN: 'number_input',
  TEXT_INPUT_SCREEN: 'text_input',
  DROPDOWN_SCREEN: 'dropdown',
};

export const screenTypeToTitle: Record<string, string> = {
  blank_screen: 'Instructional Screen',
  welcome_screen: 'Welcome Screen',
  multiple_choice: 'Multiple Choice',
  multiline_text: 'Multiline Text',
  slider: 'Slider',
  hub_spoke: 'Hub and Spoke',
  end_screen: 'End Screen',
  number_input: 'Number Input',
  text_input: 'Text Input',
  dropdown: 'Dropdown',
};

export type ScreenTypes = typeof screenTypes[number];

export const createScreen = (screenType: string): IActivityTemplate => {
  return {
    ...createActivityTemplate(),
    title: screenType,
  };
};
