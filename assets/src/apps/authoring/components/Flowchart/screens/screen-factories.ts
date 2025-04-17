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
  'text_slider',
  'hub_spoke',
  'end_screen',
  'number_input',
  'text_input',
  'dropdown',
];

export const screenTypeToTitle: Record<string, string> = {
  blank_screen: 'Instructional Screen',
  welcome_screen: 'Welcome Screen',
  multiple_choice: 'Multiple Choice',
  multiline_text: 'Multiline Text',
  slider: 'Slider',
  text_slider: 'Text Slider',
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
