import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { MarkupTree } from '../janus-text-flow/TextFlow';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export const DEFAULT_ACCORDION_THEME = '#0070F3';
export const DEFAULT_ACCORDION_HEIGHT = 197;
export const DEFAULT_ACCORDION_WIDTH = 480;
export const MIN_ACCORDION_SECTIONS = 1;
export const MAX_ACCORDION_SECTIONS = 10;

export interface AccordionSection {
  id: string;
  title: string;
  contentNodes: MarkupTree[];
}

export interface AccordionModel extends JanusAbsolutePositioned, JanusCustomCss {
  enabled: boolean;
  themeColor: string;
  sections: AccordionSection[];
  customCss?: string;
}

export const plainTextToDefaultNodes = (text: string): MarkupTree[] => [
  {
    tag: 'p',
    style: {},
    children: [
      {
        tag: 'span',
        style: { backgroundColor: 'transparent', color: 'inherit', fontSize: '16px' },
        children: [{ tag: 'text', text: text || ' ', children: [] }],
      },
    ],
  },
];

export const clampSectionCount = (value: unknown): number => {
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n)) return MIN_ACCORDION_SECTIONS;
  return Math.min(MAX_ACCORDION_SECTIONS, Math.max(MIN_ACCORDION_SECTIONS, Math.round(n)));
};

const DEFAULT_SECTION_CONTENT =
  'A dog is a type of domesticated animal. Known for its loyalty and faithfulness, it can be found as a welcome guest in many households across the world.';

export const createDefaultSection = (index: number, id?: string): AccordionSection => ({
  id: id || `accordion-section-${index}`,
  title: `This is panel header ${index}`,
  contentNodes: plainTextToDefaultNodes(DEFAULT_SECTION_CONTENT),
});

export const schema: JSONSchema7Object = {
  manageSections: {
    title: 'Manage Sections',
    type: 'array',
    items: { type: 'string' },
    description: 'Add, edit, and reorder accordion sections.',
  },
  themeColor: {
    title: 'Theme Color',
    type: 'string',
    description:
      'Optional header background color. Leave empty for default gray headers; pick a color to theme all section headers.',
    default: '',
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    description: 'Whether the learner can expand and collapse sections',
    default: true,
  },
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  customCss: {
    title: 'Custom CSS',
    type: 'string',
    description: 'Custom CSS or an @import url(...) for an external stylesheet',
    default: '',
  },
};

export const uiSchema = {
  manageSections: { 'ui:widget': 'AccordionManageEditor' },
  sections: { 'ui:widget': 'hidden' },
  themeColor: { 'ui:widget': 'ColorPicker' },
  customCss: {
    'ui:widget': 'textarea',
    'ui:options': { rows: 4 },
  },
};

export const adaptivitySchema = {
  userOpened: CapiVariableTypes.BOOLEAN,
  openedSectionsCount: CapiVariableTypes.NUMBER,
  expandedSections: CapiVariableTypes.ARRAY,
  enabled: CapiVariableTypes.BOOLEAN,
};

export const createSchema = (): Partial<AccordionModel> => ({
  enabled: true,
  customCssClass: '',
  themeColor: '',
  customCss: '',
  width: DEFAULT_ACCORDION_WIDTH,
  height: DEFAULT_ACCORDION_HEIGHT,
  sections: [createDefaultSection(1), createDefaultSection(2), createDefaultSection(3)],
});
