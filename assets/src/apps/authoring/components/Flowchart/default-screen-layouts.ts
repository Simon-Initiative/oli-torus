import { createSchema as createDropdownSchema } from '../../../../components/parts/janus-dropdown/schema';
import { createSchema as createHubSpokeSchema } from '../../../../components/parts/janus-hub-spoke/schema';
import { createSchema as createImageSchema } from '../../../../components/parts/janus-image/schema';
import { createSchema as createInputNumberSchema } from '../../../../components/parts/janus-input-number/schema';
import { createSchema as createInputTextSchema } from '../../../../components/parts/janus-input-text/schema';
import { createSchema as createMcqSchema } from '../../../../components/parts/janus-mcq/schema';
import { createSchema as createMultilineSchema } from '../../../../components/parts/janus-multi-line-text/schema';
import { createSchema as createSliderSchema } from '../../../../components/parts/janus-slider/schema';
import { createSchema as createTextSliderSchema } from '../../../../components/parts/janus-text-slider/schema';
import { IPartLayout } from '../../../delivery/store/features/activities/slice';
import { Template } from './template-types';

export const WIDTH = {
  FULL: 960,
  LEFT: 470,
  RIGHT: 471,
} as const;

export type ResponsiveWidth = typeof WIDTH[keyof typeof WIDTH];

const LAYOUT_OWNER = 'adaptive_activity_default_layout';

const TITLE_TEXT = 'Screen Title';
const LONG_PARAGRAPH_TEXT =
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam.';
const SHORT_PARAGRAPH_TEXT =
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor.';

const TRANSPARENT_PALETTE = {
  backgroundColor: 'rgba(255,255,255,0)',
  borderColor: 'rgba(255,255,255,0)',
  borderRadius: 0,
  borderStyle: 'solid' as const,
  borderWidth: '0.1px',
  useHtmlProps: true,
};

const TEXT_TAG_HEIGHT: Record<'h4' | 'p', number> = {
  h4: 22,
  p: 96,
};

/** Combined height of two welcome/end paragraphs plus spacing between them. */
const WELCOME_END_IMAGE_HEIGHT = TEXT_TAG_HEIGHT.p * 2 + 20;

export const INTERACTIVE_SCREEN_TYPES = [
  'multiple_choice',
  'multiline_text',
  'slider',
  'text_slider',
  'number_input',
  'text_input',
  'dropdown',
  'hub_spoke',
] as const;

export type InteractiveScreenType = typeof INTERACTIVE_SCREEN_TYPES[number];

const SCREEN_TYPE_TO_PART_TYPE: Record<InteractiveScreenType, string> = {
  multiple_choice: 'janus-mcq',
  text_input: 'janus-input-text',
  number_input: 'janus-input-number',
  dropdown: 'janus-dropdown',
  multiline_text: 'janus-multi-line-text',
  slider: 'janus-slider',
  text_slider: 'janus-text-slider',
  hub_spoke: 'janus-hub-spoke',
};

const isInteractiveScreenType = (screenType: string): screenType is InteractiveScreenType =>
  (INTERACTIVE_SCREEN_TYPES as readonly string[]).includes(screenType);

const textNodes = (tag: 'h4' | 'p', text: string) => [
  {
    tag,
    children: [
      {
        tag: 'span',
        style: {},
        children: [{ tag: 'text', text, children: [] }],
      },
    ],
    style: {},
  },
];

const createTextPart = ({
  id,
  tag,
  text,
  width,
}: {
  id: string;
  tag: 'h4' | 'p';
  text: string;
  width: ResponsiveWidth;
}): IPartLayout => ({
  id,
  type: 'janus-text-flow',
  custom: {
    customCssClass: '',
    height: TEXT_TAG_HEIGHT[tag],
    maxScore: 1,
    nodes: textNodes(tag, text),
    overrideHeight: false,
    overrideWidth: true,
    palette: TRANSPARENT_PALETTE,
    requiresManualGrading: false,
    visible: true,
    width: 100,
    responsiveLayoutWidth: width,
    x: 0,
    y: 0,
    z: 0,
  },
});

const questionSchemaForScreenType = (
  screenType: InteractiveScreenType,
): Record<string, unknown> => {
  switch (screenType) {
    case 'multiple_choice':
      return createMcqSchema() as Record<string, unknown>;
    case 'text_input':
      return createInputTextSchema() as Record<string, unknown>;
    case 'number_input':
      return createInputNumberSchema() as Record<string, unknown>;
    case 'dropdown':
      return createDropdownSchema() as Record<string, unknown>;
    case 'multiline_text':
      return createMultilineSchema() as Record<string, unknown>;
    case 'slider':
      return createSliderSchema() as Record<string, unknown>;
    case 'text_slider':
      return createTextSliderSchema() as Record<string, unknown>;
    case 'hub_spoke':
      return createHubSpokeSchema() as Record<string, unknown>;
  }
};

const defaultQuestionHeight = (screenType: InteractiveScreenType): number => {
  if (screenType === 'hub_spoke') {
    return 200;
  }
  if (screenType === 'multiline_text') {
    return 120;
  }
  if (screenType === 'multiple_choice') {
    return 100;
  }
  return 80;
};

const createQuestionPart = ({
  id,
  screenType,
  width,
}: {
  id: string;
  screenType: InteractiveScreenType;
  width: ResponsiveWidth;
}): IPartLayout => {
  const partType = SCREEN_TYPE_TO_PART_TYPE[screenType];
  return {
    id,
    type: partType,
    custom: {
      ...questionSchemaForScreenType(screenType),
      customCssClass: '',
      height: defaultQuestionHeight(screenType),
      maxScore: 1,
      requiresManualGrading: false,
      width: 100,
      responsiveLayoutWidth: width,
      x: 0,
      y: 0,
      z: 0,
    },
  };
};

const createImagePart = ({
  id,
  width,
  height = 200,
}: {
  id: string;
  width: ResponsiveWidth;
  height?: number;
}): IPartLayout => {
  const imageDefaults = createImageSchema();
  return {
    id,
    type: 'janus-image',
    custom: {
      ...imageDefaults,
      alt: imageDefaults.alt || 'an image',
      height,
      maxScore: 1,
      requiresManualGrading: false,
      width: 100,
      responsiveLayoutWidth: width,
      x: 0,
      y: 0,
      z: 0,
    },
  };
};

const isQuestionPartType = (type: string) => Object.values(SCREEN_TYPE_TO_PART_TYPE).includes(type);

const buildLayout = (partsLayout: IPartLayout[]): Pick<Template, 'parts' | 'partsLayout'> => ({
  partsLayout,
  parts: partsLayout.map((part) => {
    if (isQuestionPartType(part.type)) {
      return {
        gradingApproach: 'automatic' as const,
        id: part.id,
        inherited: false,
        outOf: 1,
        owner: LAYOUT_OWNER,
        type: part.type,
      };
    }
    return {
      id: part.id,
      inherited: false,
      owner: LAYOUT_OWNER,
      type: part.type,
    };
  }),
});

export const buildWelcomeEndDefaultLayout = (): Pick<Template, 'parts' | 'partsLayout'> =>
  buildLayout([
    createTextPart({ id: 'header-1', tag: 'h4', text: TITLE_TEXT, width: WIDTH.FULL }),
    createImagePart({ id: 'image-1', width: WIDTH.RIGHT, height: WELCOME_END_IMAGE_HEIGHT }),
    createTextPart({ id: 'para-1', tag: 'p', text: LONG_PARAGRAPH_TEXT, width: WIDTH.LEFT }),
    createTextPart({ id: 'para-2', tag: 'p', text: LONG_PARAGRAPH_TEXT, width: WIDTH.LEFT }),
  ]);

export const buildInstructionalDefaultLayout = (): Pick<Template, 'parts' | 'partsLayout'> =>
  buildLayout([
    createTextPart({ id: 'header-1', tag: 'h4', text: TITLE_TEXT, width: WIDTH.FULL }),
    createTextPart({ id: 'para-1', tag: 'p', text: LONG_PARAGRAPH_TEXT, width: WIDTH.FULL }),
    createTextPart({ id: 'para-2', tag: 'p', text: SHORT_PARAGRAPH_TEXT, width: WIDTH.FULL }),
  ]);

export const buildInteractiveDefaultLayout = (
  screenType: InteractiveScreenType,
): Pick<Template, 'parts' | 'partsLayout'> =>
  buildLayout([
    createTextPart({ id: 'header-1', tag: 'h4', text: TITLE_TEXT, width: WIDTH.FULL }),
    createTextPart({ id: 'para-1', tag: 'p', text: LONG_PARAGRAPH_TEXT, width: WIDTH.FULL }),
    createTextPart({ id: 'para-2', tag: 'p', text: SHORT_PARAGRAPH_TEXT, width: WIDTH.FULL }),
    createQuestionPart({ id: 'question-1', screenType, width: WIDTH.FULL }),
  ]);

export const buildDefaultLayoutForScreenType = (
  screenType: string,
): Pick<Template, 'parts' | 'partsLayout'> => {
  if (screenType === 'welcome_screen' || screenType === 'end_screen') {
    return buildWelcomeEndDefaultLayout();
  }
  if (isInteractiveScreenType(screenType)) {
    return buildInteractiveDefaultLayout(screenType);
  }
  return buildInstructionalDefaultLayout();
};

interface ActivityModelWithAuthoring {
  partsLayout: IPartLayout[];
  authoring: {
    parts: Template['parts'];
    flowchart?: {
      templateApplied?: boolean;
      [key: string]: unknown;
    };
    [key: string]: unknown;
  };
  [key: string]: unknown;
}

export const applyDefaultLayoutToModel = (
  model: ActivityModelWithAuthoring,
  screenType: string,
): void => {
  const { parts, partsLayout } = buildDefaultLayoutForScreenType(screenType);
  model.partsLayout = partsLayout;
  model.authoring.parts = parts;
  if (model.authoring.flowchart) {
    model.authoring.flowchart.templateApplied = true;
  }
};
