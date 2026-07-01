import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export const DEFAULT_LIST_SORT_BAR_COLOR = 'rgb(46, 159, 255)';
export const DEFAULT_LIST_SORT_HEIGHT = 260;

export interface ListSortItem {
  id: string;
  text: string;
}

export interface ListSortModel extends JanusAbsolutePositioned, JanusCustomCss {
  // listItems are stored in the author-defined correct order; this is the source of truth
  // for correctness. The list is shuffled for the learner when `randomize` is true.
  listItems: ListSortItem[];
  showHeaderFooter: boolean;
  headerLabel: string;
  footerLabel: string;
  randomize: boolean;
  barColor: string;
  enabled: boolean;
  showHints?: boolean;
  customCss?: string;
}

export const schema: JSONSchema7Object = {
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  showHeaderFooter: {
    title: 'Show Header & Footer',
    type: 'boolean',
    description: 'specifies whether the header and footer labels are visible',
    default: true,
  },
  headerLabel: {
    title: 'Header Label',
    type: 'string',
    default: 'First',
  },
  footerLabel: {
    title: 'Footer Label',
    type: 'string',
    default: 'Last',
  },
  randomize: {
    title: 'Randomize Order For Learner',
    type: 'boolean',
    description: 'specifies whether the list is shuffled for the learner',
    default: true,
  },
  barColor: {
    title: 'Bar Color',
    type: 'string',
    description: 'color value used for the component color scheme (e.g. rgb(46, 159, 255))',
    default: DEFAULT_LIST_SORT_BAR_COLOR,
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    description: 'specifies whether the learner can interact with the component',
    default: true,
  },
  showHints: {
    title: 'Show Hints',
    type: 'boolean',
    description:
      'When enabled, marks items in the correct position with a green border and check; wrong position with red border and cross',
    default: false,
  },
  listItems: {
    title: 'List Items',
    type: 'array',
    items: { type: 'object' },
  },
  customCss: {
    title: 'Custom CSS',
    type: 'string',
    description: 'custom CSS or an external stylesheet import for this component',
  },
};

export const uiSchema = {
  barColor: {
    'ui:widget': 'ColorPicker',
  },
  listItems: {
    'ui:widget': 'ListSortItemsEditor',
  },
  customCss: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 4,
    },
  },
};

export const simpleSchema: JSONSchema7Object = {
  showHeaderFooter: {
    title: 'Show Header & Footer',
    type: 'boolean',
    default: true,
  },
  headerLabel: {
    title: 'Header Label',
    type: 'string',
    default: 'First',
  },
  footerLabel: {
    title: 'Footer Label',
    type: 'string',
    default: 'Last',
  },
  randomize: {
    title: 'Randomize Order For Learner',
    type: 'boolean',
    default: true,
  },
  barColor: {
    title: 'Bar Color',
    type: 'string',
    description: 'color value used for the component color scheme (e.g. rgb(46, 159, 255))',
    default: DEFAULT_LIST_SORT_BAR_COLOR,
  },
  showHints: {
    title: 'Show Hints',
    type: 'boolean',
    description:
      'When enabled, marks items in the correct position with a green border and check; wrong position with red border and cross',
    default: false,
  },
  listItems: {
    title: 'List Items',
    type: 'array',
    items: { type: 'object' },
  },
  customCss: {
    title: 'Custom CSS',
    type: 'string',
  },
};

export const simpleUISchema = {
  'ui:order': [
    'headerLabel',
    'footerLabel',
    'showHeaderFooter',
    'randomize',
    'barColor',
    'showHints',
    'listItems',
    'customCss',
  ],
  barColor: {
    'ui:widget': 'ColorPicker',
  },
  listItems: {
    'ui:widget': 'ListSortItemsEditor',
  },
  customCss: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 4,
    },
  },
};

export const adaptivitySchema = {
  enabled: CapiVariableTypes.BOOLEAN,
  userModified: CapiVariableTypes.BOOLEAN,
  correct: CapiVariableTypes.BOOLEAN,
  showAnswer: CapiVariableTypes.BOOLEAN,
  showHints: CapiVariableTypes.BOOLEAN,
  barColor: CapiVariableTypes.STRING,
  currentItemList: CapiVariableTypes.ARRAY,
  customCss: CapiVariableTypes.STRING,
};

export const getCapabilities = () => ({
  configure: false,
  canUseExpression: true,
});

const makeItem = (text: string): ListSortItem => ({
  id: `item-${Math.random().toString(36).slice(2, 10)}`,
  text,
});

export const createSchema = (): Partial<ListSortModel> => {
  const items = [makeItem('Clouds'), makeItem('Mountains'), makeItem('Grass/Rocks')];

  return {
    width: '100%',
    height: DEFAULT_LIST_SORT_HEIGHT,
    enabled: true,
    customCssClass: '',
    listItems: items,
    showHeaderFooter: true,
    headerLabel: 'Slowest',
    footerLabel: 'Fastest',
    randomize: true,
    barColor: DEFAULT_LIST_SORT_BAR_COLOR,
    showHints: false,
    customCss: '',
  };
};
