import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export const DEFAULT_MATCHING_MIN_HEIGHT = 280;
export const RESPONSIVE_MATCHING_MIN_HEIGHT = 280;
export const DEFAULT_MATCHING_THEME = '#0070F3';

export type MatchingItemType = 'text' | 'image';

export interface MatchingItem {
  // unique, stable id used internally for matching and correct-answer mapping
  id: string;
  type: MatchingItemType;
  // short label, acts as the unique human identifier used in CAPI keys
  label: string;
  // text content (used when type === 'text'); falls back to label when empty
  text?: string;
  // image source (used when type === 'image')
  imageSrc?: string;
  // alternative text for the image (accessibility)
  alt?: string;
  // maximum number of links this item may participate in
  maxLinks: number;
}

export type MatchingMatches = Record<string, string[]>;

export interface MatchingModel extends JanusAbsolutePositioned, JanusCustomCss {
  enabled: boolean;
  // hex color theme applied to the component (e.g. #0070F3)
  themeColor: string;
  showColumnTitles: boolean;
  column1Title: string;
  column2Title: string;
  column1Items: MatchingItem[];
  column2Items: MatchingItem[];
  // maps column-1 item id -> array of column-2 item ids
  correctMatches: MatchingMatches;
  // author-provided custom CSS or @import statements
  customCss?: string;
  showHints?: boolean;
  showCorrect?: boolean;
  // shuffle both columns independently for the learner when true
  randomize?: boolean;
}

const manageDataProperties: JSONSchema7Object = {
  manageItems: {
    title: 'Manage Matching',
    type: 'array',
    items: { type: 'string' },
    description:
      'Create column items, then switch to Edit Correct State to draw the correct matches.',
  },
};

const manageDataUiSchema = {
  manageItems: { 'ui:widget': 'MatchingManageEditor' },
};

export const schema: JSONSchema7Object = {
  ...manageDataProperties,
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    description: 'specifies whether the learner can interact with the component',
    default: true,
  },
  themeColor: {
    title: 'Theme Color',
    type: 'string',
    description: 'Hex color used for the component accent (e.g. #0070F3)',
    default: DEFAULT_MATCHING_THEME,
  },
  showColumnTitles: {
    title: 'Show Column Titles',
    type: 'boolean',
    description: 'When enabled, column titles are shown above each column',
    default: true,
  },
  customCss: {
    title: 'Custom CSS',
    type: 'string',
    description: 'Custom CSS or an @import url(...) for an external stylesheet',
    default: '',
  },
  showHints: {
    title: 'Show Hints',
    type: 'boolean',
    description: 'When enabled, marks correct/incorrect matches with visual feedback',
    default: false,
  },
  randomize: {
    title: 'Randomize Order For Learner',
    type: 'boolean',
    description: 'When enabled, shuffles items in both columns independently for the learner',
    default: true,
  },
};

export const simpleSchema: JSONSchema7Object = {
  ...manageDataProperties,
  themeColor: {
    title: 'Theme Color',
    type: 'string',
    description: 'Hex color used for the component accent (e.g. #0070F3)',
    default: DEFAULT_MATCHING_THEME,
  },
  showColumnTitles: {
    title: 'Show Column Titles',
    type: 'boolean',
    description: 'When enabled, column titles are shown above each column',
    default: true,
  },
  customCss: {
    title: 'Custom CSS',
    type: 'string',
    description: 'Custom CSS or an @import url(...) for an external stylesheet',
    default: '',
  },
  showHints: {
    title: 'Show Hints',
    type: 'boolean',
    description: 'When enabled, marks correct/incorrect matches with visual feedback',
    default: false,
  },
  randomize: {
    title: 'Randomize Order For Learner',
    type: 'boolean',
    description: 'When enabled, shuffles items in both columns independently for the learner',
    default: true,
  },
};

export const uiSchema = {
  'ui:order': ['manageItems', '*'],
  ...manageDataUiSchema,
  themeColor: {
    'ui:widget': 'ColorPicker',
  },
  customCss: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 4,
    },
  },
};

export const simpleUiSchema = {
  'ui:order': [
    'manageItems',
    'themeColor',
    'showColumnTitles',
    'showHints',
    'randomize',
    'customCss',
  ],
  ...manageDataUiSchema,
  themeColor: {
    'ui:widget': 'ColorPicker',
  },
  customCss: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 4,
    },
  },
};

/**
 * Adaptivity schema is dynamic: in addition to the always-present control and
 * status variables, it exposes one Matches array per column-1 item (keyed by
 * the item's short label).
 */
export const adaptivitySchema = ({ currentModel }: { currentModel: any }) => {
  const adaptivity: Record<string, CapiVariableTypes> = {};
  adaptivity.enabled = CapiVariableTypes.BOOLEAN;
  adaptivity.userModified = CapiVariableTypes.BOOLEAN;
  adaptivity.correct = CapiVariableTypes.BOOLEAN;
  adaptivity.showCorrect = CapiVariableTypes.BOOLEAN;
  adaptivity.showHints = CapiVariableTypes.BOOLEAN;
  adaptivity.randomize = CapiVariableTypes.BOOLEAN;
  adaptivity.matchCount = CapiVariableTypes.NUMBER;

  const column1Items: MatchingItem[] = currentModel?.custom?.column1Items || [];
  column1Items.forEach((item, index) => {
    const label = (item?.label || `Item ${index + 1}`).trim();
    adaptivity[`${label}.Matches`] = CapiVariableTypes.ARRAY;
  });

  return adaptivity;
};

export const getCapabilities = () => ({
  configure: false,
});

export const createSchema = (): Partial<MatchingModel> => {
  const column1Items: MatchingItem[] = [
    {
      id: 'match-c1-1',
      type: 'text',
      label: 'Item 1',
      text: 'Item 1',
      maxLinks: 1,
    },
    {
      id: 'match-c1-2',
      type: 'text',
      label: 'Item 2',
      text: 'Item 2',
      maxLinks: 1,
    },
    {
      id: 'match-c1-3',
      type: 'text',
      label: 'Item 3',
      text: 'Item 3',
      maxLinks: 1,
    },
  ];

  const column2Items: MatchingItem[] = [
    {
      id: 'match-c2-1',
      type: 'text',
      label: 'Match 1',
      text: 'Match 1',
      maxLinks: 1,
    },
    {
      id: 'match-c2-2',
      type: 'text',
      label: 'Match 2',
      text: 'Match 2',
      maxLinks: 1,
    },
    {
      id: 'match-c2-3',
      type: 'text',
      label: 'Match 3',
      text: 'Match 3',
      maxLinks: 1,
    },
  ];

  return {
    enabled: true,
    customCssClass: '',
    themeColor: DEFAULT_MATCHING_THEME,
    showColumnTitles: true,
    column1Title: 'Column 1',
    column2Title: 'Column 2',
    customCss: '',
    height: DEFAULT_MATCHING_MIN_HEIGHT,
    showHints: false,
    showCorrect: false,
    randomize: true,
    column1Items,
    column2Items,
    correctMatches: {
      'match-c1-1': ['match-c2-1'],
      'match-c1-2': ['match-c2-2'],
      'match-c1-3': ['match-c2-3'],
    },
  };
};
