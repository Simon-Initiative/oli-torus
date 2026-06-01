import { IPartLayout } from '../../../delivery/store/features/activities/slice';
import { createSchema as createDropdownSchema } from '../../../../components/parts/janus-dropdown/schema';
import { createSchema as createHubSpokeSchema } from '../../../../components/parts/janus-hub-spoke/schema';
import { createSchema as createImageSchema } from '../../../../components/parts/janus-image/schema';
import { createSchema as createInputNumberSchema } from '../../../../components/parts/janus-input-number/schema';
import { createSchema as createInputTextSchema } from '../../../../components/parts/janus-input-text/schema';
import { createSchema as createMcqSchema } from '../../../../components/parts/janus-mcq/schema';
import { createSchema as createMultilineSchema } from '../../../../components/parts/janus-multi-line-text/schema';
import { createSchema as createSliderSchema } from '../../../../components/parts/janus-slider/schema';
import { createSchema as createTextSliderSchema } from '../../../../components/parts/janus-text-slider/schema';
import { createSchema as createVideoSchema } from '../../../../components/parts/janus-video/schema';
import { screenTypeToTitle } from './screens/screen-factories';
import { Template } from './template-types';

export const WIDTH = {
  FULL: 960,
  LEFT: 470,
  RIGHT: 471,
} as const;

export type ResponsiveWidth = (typeof WIDTH)[keyof typeof WIDTH];

const TEMPLATE_OWNER = 'adaptive_activity_responsive_template';

const HEADER_TEXT = 'Lorem ipsum';
const PARAGRAPH_TEXT =
  'Lorem ipsum dolor sit amet consectetur. Non feugiat tincidunt ante arcu urna sed consectetur.';
const PROMPT_TEXT = 'Answer the question below.';

const TRANSPARENT_PALETTE = {
  backgroundColor: 'rgba(255,255,255,0)',
  borderColor: 'rgba(255,255,255,0)',
  borderRadius: 0,
  borderStyle: 'solid' as const,
  borderWidth: '0.1px',
  useHtmlProps: true,
};

const TEXT_TAG_HEIGHT: Record<'h4' | 'h2' | 'p', number> = {
  h4: 22,
  h2: 96,
  p: 96,
};

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

export type InteractiveScreenType = (typeof INTERACTIVE_SCREEN_TYPES)[number];

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

type PartSlot =
  | {
      kind: 'text';
      id: string;
      tag: 'h4' | 'h2' | 'p';
      width: ResponsiveWidth;
      text?: string;
      height?: number;
    }
  | { kind: 'question'; id: string; width: ResponsiveWidth }
  | { kind: 'image'; id: string; width: ResponsiveWidth }
  | { kind: 'video'; id: string; width: ResponsiveWidth };

const textNodes = (tag: 'h4' | 'h2' | 'p', text: string) => [
  {
    tag,
    children: [
      {
        tag: 'span',
        style: tag === 'p' ? {} : {},
        children: [{ tag: 'text', text, children: [] }],
      },
    ],
    style: {},
  },
];

export const createResponsiveTextPart = ({
  id,
  tag,
  text,
  width,
  height,
}: {
  id: string;
  tag: 'h4' | 'h2' | 'p';
  text: string;
  width: ResponsiveWidth;
  height?: number;
}): IPartLayout => ({
  id,
  type: 'janus-text-flow',
  custom: {
    customCssClass: '',
    height: height ?? TEXT_TAG_HEIGHT[tag],
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

const questionSchemaForScreenType = (screenType: InteractiveScreenType): Record<string, unknown> => {
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

export const createResponsiveQuestionPart = ({
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

export const createResponsiveImagePart = ({
  id,
  width,
}: {
  id: string;
  width: ResponsiveWidth;
}): IPartLayout => {
  const imageDefaults = createImageSchema();
  return {
    id,
    type: 'janus-image',
    custom: {
      ...imageDefaults,
      alt: imageDefaults.alt || 'an image',
      height: 200,
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

export const createResponsiveVideoPart = ({
  id,
  width,
}: {
  id: string;
  width: ResponsiveWidth;
}): IPartLayout => ({
  id,
  type: 'janus-video',
  custom: {
    ...createVideoSchema(),
    height: 200,
    maxScore: 1,
    requiresManualGrading: false,
    width: 100,
    responsiveLayoutWidth: width,
    x: 0,
    y: 0,
    z: 0,
  },
});

const materializeSlot = (
  slot: PartSlot,
  screenType?: InteractiveScreenType,
): IPartLayout => {
  switch (slot.kind) {
    case 'text':
      return createResponsiveTextPart({
        id: slot.id,
        tag: slot.tag,
        text: slot.text ?? (slot.tag === 'h4' ? HEADER_TEXT : PARAGRAPH_TEXT),
        width: slot.width,
        height: slot.height,
      });
    case 'question':
      if (!screenType) {
        throw new Error('Question slot requires screenType');
      }
      return createResponsiveQuestionPart({ id: slot.id, screenType, width: slot.width });
    case 'image':
      return createResponsiveImagePart({ id: slot.id, width: slot.width });
    case 'video':
      return createResponsiveVideoPart({ id: slot.id, width: slot.width });
  }
};

const isQuestionPartType = (type: string) =>
  Object.values(SCREEN_TYPE_TO_PART_TYPE).includes(type);

export const buildTemplate = ({
  name,
  templateType,
  slots,
  screenType,
}: {
  name: string;
  templateType: string;
  slots: PartSlot[];
  screenType?: InteractiveScreenType;
}): Template => {
  const partsLayout = slots.map((slot) => materializeSlot(slot, screenType));

  const parts: Template['parts'] = partsLayout.map((part) => {
    if (isQuestionPartType(part.type)) {
      return {
        gradingApproach: 'automatic' as const,
        id: part.id,
        inherited: false,
        outOf: 1,
        owner: TEMPLATE_OWNER,
        type: part.type,
      };
    }
    return {
      id: part.id,
      inherited: false,
      owner: TEMPLATE_OWNER,
      type: part.type,
    };
  });

  return {
    name,
    templateType,
    layoutMode: 'responsive',
    parts,
    partsLayout,
  };
};

const header = (): PartSlot => ({ kind: 'text', id: 'header-1', tag: 'h4', width: WIDTH.FULL });
const para = (id: string, width: ResponsiveWidth, text?: string): PartSlot => ({
  kind: 'text',
  id,
  tag: 'p',
  width,
  text,
});
const question = (id: string, width: ResponsiveWidth): PartSlot => ({
  kind: 'question',
  id,
  width,
});
const image = (id: string, width: ResponsiveWidth): PartSlot => ({
  kind: 'image',
  id,
  width,
});
const video = (id: string, width: ResponsiveWidth): PartSlot => ({
  kind: 'video',
  id,
  width,
});

const INTERACTIVE_LAYOUT_SLOTS: Record<
  number,
  (screenType: InteractiveScreenType) => PartSlot[]
> = {
  1: () => [
    header(),
    para('para-1', WIDTH.LEFT),
    question('question-1', WIDTH.RIGHT),
    para('para-2', WIDTH.FULL),
  ],
  2: () => [
    header(),
    question('question-1', WIDTH.LEFT),
    para('para-1', WIDTH.RIGHT),
    para('para-2', WIDTH.FULL),
  ],
  3: () => [
    header(),
    para('para-1', WIDTH.FULL),
    question('question-1', WIDTH.LEFT),
    para('para-2', WIDTH.RIGHT, PROMPT_TEXT),
    para('para-3', WIDTH.FULL),
  ],
  4: () => [
    header(),
    para('para-1', WIDTH.LEFT),
    para('para-2', WIDTH.RIGHT),
    question('question-1', WIDTH.FULL),
    para('para-3', WIDTH.FULL),
  ],
  5: () => [
    header(),
    para('para-1', WIDTH.LEFT),
    question('question-1', WIDTH.RIGHT),
    para('para-2', WIDTH.LEFT),
    para('para-3', WIDTH.RIGHT),
    para('para-4', WIDTH.FULL),
  ],
  6: () => [
    header(),
    para('para-1', WIDTH.LEFT),
    para('para-2', WIDTH.RIGHT),
    question('question-1', WIDTH.FULL),
    para('para-3', WIDTH.LEFT),
    para('para-4', WIDTH.RIGHT),
    para('para-5', WIDTH.FULL),
  ],
};

const INTERACTIVE_LAYOUT_NAMES: Record<number, string> = {
  1: 'Layout 1 – Text + Question',
  2: 'Layout 2 – Question + Text',
  3: 'Layout 3 – Full Text + Question Row',
  4: 'Layout 4 – Two Text Columns + Question',
  5: 'Layout 5 – Alternating Layout',
  6: 'Layout 6 – Mixed Content',
};

export const buildInteractiveTemplatesForType = (
  screenType: InteractiveScreenType,
): Template[] => {
  const typeLabel = screenTypeToTitle[screenType] || screenType;
  return [1, 2, 3, 4, 5, 6].map((layoutNumber) => {
    const slots = INTERACTIVE_LAYOUT_SLOTS[layoutNumber](screenType);
    return buildTemplate({
      name: `${INTERACTIVE_LAYOUT_NAMES[layoutNumber]} (${typeLabel})`,
      templateType: screenType,
      slots,
      screenType,
    });
  });
};

const INSTRUCTIONAL_LAYOUT_SLOTS: Record<number, PartSlot[]> = {
  1: [header(), para('para-1', WIDTH.FULL)],
  2: [header(), para('para-1', WIDTH.LEFT), para('para-2', WIDTH.RIGHT)],
  3: [header(), para('para-1', WIDTH.LEFT), image('image-1', WIDTH.RIGHT)],
  4: [header(), image('image-1', WIDTH.LEFT), para('para-1', WIDTH.RIGHT)],
  5: [header(), image('image-1', WIDTH.LEFT), video('video-1', WIDTH.RIGHT), para('para-1', WIDTH.FULL)],
  6: [header(), para('para-1', WIDTH.FULL), image('image-1', WIDTH.LEFT), para('para-2', WIDTH.FULL)],
};

const INSTRUCTIONAL_LAYOUT_NAMES: Record<number, string> = {
  1: 'Instructional 1 – Header + body',
  2: 'Instructional 2 – Two text columns',
  3: 'Instructional 3 – Text + image',
  4: 'Instructional 4 – Image + text',
  5: 'Instructional 5 – Image + video row',
  6: 'Instructional 6 – Stacked text and image',
};

export const instructionalTemplates: Template[] = [1, 2, 3, 4, 5, 6].map((layoutNumber) =>
  buildTemplate({
    name: INSTRUCTIONAL_LAYOUT_NAMES[layoutNumber],
    templateType: 'blank_screen',
    slots: INSTRUCTIONAL_LAYOUT_SLOTS[layoutNumber],
  }),
);
