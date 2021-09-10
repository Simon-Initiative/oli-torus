import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface PopupModel extends JanusAbsolutePositioned, JanusCustomCss {
  description: string;
  showLabel: boolean;
  openByDefault: boolean;
  defaultURL: string;
  iconURL: string;
  useToggleBehavior: boolean;
  isOpen: boolean;
  visible: boolean;
  popup: any; // TODO: layout model
}

export const schema: JSONSchema7Object = {
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  description: {
    title: 'Description',
    type: 'string',
    default: 'Additional Information',
    description: 'provides alt text and aria-label content',
  },
  showLabel: {
    title: 'Show Label',
    type: 'boolean',
    description: 'specifies whether label is visible',
    default: true,
  },
  openByDefault: {
    title: 'Open By Default',
    type: 'boolean',
    description: 'specifies whether popup should open by default',
    default: false,
  },
  defaultURL: {
    title: 'Default URL',
    type: 'string',
    description: 'default URL for the button icon',
    default: '/repo/icons/question_mark_orange_32x32.png',
    enum: [
      '/repo/icons/question_mark_orange_32x32.png',
      '/repo/icons/question_mark_red_32x32.png',
      '/repo/icons/question_mark_green_32x32.png',
      '/repo/icons/question_mark_blue_32x32.png',
      '/repo/icons/information_mark_orange_32x32.png',
      '/repo/icons/information_mark_red_32x32.png',
      '/repo/icons/information_mark_green_32x32.png',
      '/repo/icons/information_mark_blue_32x32.png',
      '/repo/icons/exclamation_mark_orange_32x32.png',
      '/repo/icons/exclamation_mark_red_32x32.png',
      '/repo/icons/exclamation_mark_green_32x32.png',
      '/repo/icons/exclamation_mark_blue_32x32.png',
    ],
  },
  iconURL: {
    title: 'Icon URL',
    type: 'string',
    description: 'Custom URL for the button icon',
  },
  useToggleBehavior: {
    title: 'Use Toggle Behaviour',
    type: 'boolean',
    description: 'specifies whether popup toggles open/closed on click or on mouse hover',
    default: true,
  },
  isOpen: {
    title: 'Is Open',
    type: 'boolean',
    description: 'specifies whether popup is opened',
    default: false,
  },
  visible: {
    title: 'Visible',
    type: 'boolean',
    description: 'specifies whether popup will be visible on the screen',
    default: true,
  },
};

export const uiSchema = {};

export const createSchema = (): Partial<PopupModel> => ({
  customCssClass: '',
  description: '',
  questionFlow: 'LRTB',
  showLabel: true,
  openByDefault: false,
  defaultURL: '/repo/icons/question_mark_orange_32x32.png',
  iconURL: '',
  useToggleBehavior: true,
  isOpen: false,
  visible: true,
  popup: {
    custom: {
      customCssClass: '',
      x: 0,
      y: 0,
      z: 0,
      width: 350,
      height: 350,
      palette: {
        useHtmlProps: true,
        backgroundColor: '#ffffff',
        borderColor: '#ffffff',
        borderRadius: '0',
        borderStyle: 'solid',
        borderWidth: '1px',
      },
    },
    partsLayout: [
      {
        id: 'header-text',
        type: 'janus-text-flow',
        custom: {
          x: 10,
          y: 10,
          z: 0,
          width: 100,
          height: 50,
          nodes: [
            {
              tag: 'p',
              style: {},
              children: [
                {
                  tag: 'span',
                  style: {
                    color: '#000',
                    fontWeight: 'bold',
                  },
                  children: [
                    {
                      tag: 'text',
                      style: {},
                      text: 'Popup Window Text',
                      children: [],
                    },
                  ],
                },
              ],
            },
          ],
        },
      },
    ],
  },
});
