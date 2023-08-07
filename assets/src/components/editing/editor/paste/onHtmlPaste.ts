import { Editor, Element, Text, Transforms } from 'slate';
import { ModelElement } from 'data/content/model/elements/types';
import { ModelTypes, schema } from 'data/content/model/schema';
import {
  DeserializerAction,
  addEmptyChildrenAction,
  addMarkAction,
  copyAttribute,
  copyNumericAttribute,
  copyTextContent,
  tagTypeAction,
} from './deserializerActions';
import {
  DeserializeTypes,
  DeserializeTypesNoNull,
  DeserializerMatchRule,
  StyleMatcher,
  allRules,
  anyRule,
  attributeEqualsRule,
  hasAttributeRule,
  notRule,
  styleRule,
  tagNameRule,
} from './deserializerRules';

type PartialTagDeserializer = {
  name: string;
  rule: DeserializerMatchRule;
  action: DeserializerAction;
};

const isJest = typeof process !== 'undefined' && process.env.JEST_WORKER_ID !== undefined;
const DEBUG_OUTPUT = !isJest;

export const filterNullModelElements = (arr: DeserializeTypes): arr is DeserializeTypesNoNull =>
  arr != null;

/* Small factory method for creating DeserializerMatchRules, has the ability to apply one or more actions */
const serializer = (
  name: string,
  rule: DeserializerMatchRule,
  ...actions: DeserializerAction[]
): PartialTagDeserializer => {
  if (actions.length === 0) {
    throw new Error('Must have at least one action');
  }
  if (actions.length === 1) {
    return {
      name,
      rule,
      action: actions[0],
    };
  }
  return {
    name,
    rule,
    action: (el: HTMLElement) => {
      const attrs = actions.map((action) => action(el));
      return Object.assign({}, ...attrs);
    },
  };
};

export const foreignTagRule = allRules(tagNameRule('I'), hasAttributeRule('lang'));

// NOTE: rules lower in the list overwrite previous rules if they both trigger
const TAG_DESERIALIZERS: PartialTagDeserializer[] = [
  serializer('table', tagNameRule('TABLE'), tagTypeAction('table')),
  serializer('tr', tagNameRule('TR'), tagTypeAction('tr')),
  serializer(
    'td',
    tagNameRule('TD'),
    tagTypeAction('td'),
    copyNumericAttribute('colspan', 'colspan'),
    copyNumericAttribute('rowspan', 'rowspan'),
  ),
  serializer('th', tagNameRule('TH'), tagTypeAction('th')),

  serializer('ul', tagNameRule('UL'), tagTypeAction('ul')),
  serializer('ol', tagNameRule('OL'), tagTypeAction('ol')),
  serializer('li', tagNameRule('LI'), tagTypeAction('li')),

  serializer('link', tagNameRule('A'), tagTypeAction('a'), copyAttribute('href', 'href')),
  serializer('h4', tagNameRule('H4'), tagTypeAction('h4')),
  serializer('h5', tagNameRule('H5'), tagTypeAction('h5')),
  serializer('h6', tagNameRule('H6'), tagTypeAction('h6')),

  serializer(
    'h3',
    anyRule(
      tagNameRule('H3'),
      allRules(tagNameRule('SPAN'), hasAttributeRule('data-ccp-parastyle')),
    ),
    tagTypeAction('h3'),
  ),

  serializer(
    'h1',
    anyRule(
      tagNameRule('H1'),
      allRules(tagNameRule('SPAN'), attributeEqualsRule('data-ccp-parastyle', 'heading 1')),
    ),
    tagTypeAction('h1'),
  ),

  serializer(
    'h2',
    anyRule(
      tagNameRule('H2'),
      allRules(tagNameRule('SPAN'), attributeEqualsRule('data-ccp-parastyle', 'heading 2')),
    ),
    tagTypeAction('h2'),
  ),

  serializer(
    'p',
    allRules(
      tagNameRule('P'),
      notRule(
        attributeEqualsRule('role', 'heading'), // MSWord wraps headings in a paragraph with a role
      ),
    ),
    tagTypeAction('p'),
  ),

  serializer(
    'code',
    tagNameRule('PRE'),
    tagTypeAction('code'),
    addEmptyChildrenAction,
    copyTextContent('code'),
    copyAttribute('data-language', 'language', 'text'),
  ),

  serializer('foreign', foreignTagRule, tagTypeAction('foreign'), copyAttribute('lang', 'lang')),
];

const spanWithStyleRule = (styleName: string, styleValue: string[] | string | StyleMatcher) =>
  allRules(tagNameRule('SPAN'), styleRule(styleName, styleValue));

// These deserialize tags that result in marks being applied to text nodes.
const TEXT_TAGS: PartialTagDeserializer[] = [
  serializer('code', tagNameRule('CODE'), addMarkAction('code')),
  serializer(
    'del',
    anyRule(
      tagNameRule('DEL'),
      tagNameRule('S'),
      spanWithStyleRule('text-decoration', 'line-through'),
    ),
    addMarkAction('strikethrough'),
  ),

  serializer(
    'em',
    anyRule(
      tagNameRule('EM'),
      allRules(tagNameRule('I'), notRule(foreignTagRule)), // <i lang="fr"> is going to be treated as a <foreign> node and so don't count that as a mark
      spanWithStyleRule('font-style', ['italic', 'oblique']),
    ),
    addMarkAction('em'),
  ),

  serializer('strong', tagNameRule('STRONG'), addMarkAction('strong')),
  serializer(
    'b',
    anyRule(
      allRules(tagNameRule('B'), notRule(styleRule('font-weight', 'normal'))), // GDocs uses <b style="font-weight: normal"> for stupid things
      spanWithStyleRule('font-weight', ['bold', 'bolder', '700']),
      // Either a <b> or a <span> with a bold font-weight
    ),
    addMarkAction('strong'),
  ),

  serializer(
    'u',
    anyRule(tagNameRule('U'), spanWithStyleRule('text-decoration', 'underline')),
    addMarkAction('underline'),
  ),

  serializer(
    'sub',

    anyRule(
      tagNameRule('SUB'),
      spanWithStyleRule('vertical-align', 'sub'), // MSWord
    ),

    addMarkAction('sub'),
  ),

  serializer(
    'sup',
    anyRule(
      tagNameRule('SUP'),
      spanWithStyleRule('vertical-align', 'super'), // MSWord
    ),
    addMarkAction('sup'),
  ),

  serializer('small', tagNameRule('SMALL'), addMarkAction('deemphasis')),
];

export const getRuleForTest = (name: string) =>
  TAG_DESERIALIZERS.find(({ name: n }) => n === name) ||
  TEXT_TAGS.find(({ name: n }) => n === name);

const addToTextNode =
  (attrs: Record<string, boolean>) =>
  (node: Text | ModelElement): Text | ModelElement => {
    if (!Text.isText(node)) {
      if (node.children) {
        (node as any).children = node.children.map(addToTextNode(attrs));
      }
      return node;
    }

    // Special case: if we're adding subscript to a node with subscript, it's double sub script instead
    if (attrs.sub && node.sub) {
      delete attrs.sub;
      delete node.sub;
      attrs.doublesub = true;
    }

    // Special case: if we're adding subscript to a node with double subscript, ignore it
    if (attrs.sub && node.doublesub) {
      delete attrs.sub;
    }

    return { ...node, ...attrs };
  };

const sanitizeText = (text: string) => text.replace(/[\u00a0]/g, ' ').replace(/[\n\r]+/g, ' ');

const deserialize = (el: HTMLElement): DeserializeTypes => {
  if (el.nodeType === 3 && el.textContent) {
    return [{ text: sanitizeText(el.textContent) }];
  } else if (el.nodeType !== 1) {
    return null;
  }

  const { nodeName } = el;
  const parent: ChildNode = el;

  let children: DeserializeTypesNoNull = Array.from(parent.childNodes)
    .map(deserialize)
    .filter(filterNullModelElements)
    .flat();

  if (children.length === 0) {
    children = [{ text: '' }];
  }

  if (nodeName === 'BODY') {
    return children;
  }

  /* Run through all our TEXT_TAGS rules and collect all the results from them for this element.
     These are going to be marks we add to the text nodes that are children of this element.
  */
  const textAttributesArray = TEXT_TAGS.filter(({ rule }) => rule(el))
    .map(({ action, name }) => {
      DEBUG_OUTPUT && console.info('Matched mark rule', name);
      return action(el);
    })
    .filter((r) => r != null);
  const textAttributes = Object.assign({}, ...textAttributesArray);
  if (textAttributes) {
    children = children.map(addToTextNode(textAttributes));
  }

  /* Run through all our TAG_DESERIALIZER rules and collect all the results from them for this element. */
  const elementAttributesArray = TAG_DESERIALIZERS.filter(({ rule }) => rule(el))
    .map(({ action, name }) => {
      DEBUG_OUTPUT && console.info('Matched rule', name);
      return action(el);
    })
    .filter((r) => r != null);
  const elementAttributes = Object.assign({}, ...elementAttributesArray);

  /* We our rules added a type prop (and maybe lots of other stuff) to the elementAttributes, we're going to treat it as an element.
     If we have a children prop, we're good to go (ex: the code node will want an empty children array and adds that in the rules)
     If not, we need to add that in.
  */
  if (elementAttributes.type) {
    if (!elementAttributes.children) {
      elementAttributes.children = children;
    }
    return elementAttributes as ModelElement;
  }

  return children;
};

const isBlock = (type: ModelTypes) => !!schema[type]?.isBlock;

/*  Sometimes, we end up with empty text nodes as siblings to block nodes. This is bad, so we remove them.
    Example:
    [
      {text:''},
      {
        type: 'p',
        children: [{text:'Real content'}]
      },
      {text:''},
    ]

    =>

     [
      {
        type: 'p',
        children: [{text:'Real content'}]
      }
    ]
*/
const removeEmptyTextNodesNextToBlockNodes = (
  fragment: (ModelElement | Text)[],
): (ModelElement | Text)[] => {
  // Process children first
  fragment = fragment.map((node) => {
    if (Element.isElement(node) && node.children) {
      return {
        ...node,
        children: removeEmptyTextNodesNextToBlockNodes(node.children),
      } as ModelElement | Text;
    }
    return node;
  });

  const hasBlockNode = fragment.some((node) => Element.isElement(node) && isBlock(node.type));
  if (!hasBlockNode) return fragment;

  // Remove any empty text nodes.
  return fragment.filter((node) => {
    if (Text.isText(node) && node.text.trim() === '') return false;
    return true;
  });
};

export const onHTMLPaste = (event: React.ClipboardEvent<HTMLDivElement>, editor: Editor) => {
  const pastedHtml = event.clipboardData?.getData('text/html')?.trim();

  if (!pastedHtml) return;
  debugger;
  try {
    const parsed = new DOMParser().parseFromString(pastedHtml, 'text/html');
    const [body] = Array.from(parsed.getElementsByTagName('body'));
    let fragment = deserialize(body);

    if (!fragment) return;
    if (!Array.isArray(fragment)) fragment = [fragment];
    event.preventDefault();
    fragment = removeEmptyTextNodesNextToBlockNodes(fragment as (ModelElement | Text)[]);
    Transforms.insertFragment(editor, fragment);
  } catch (e) {
    console.error('Could not parse pasted html', e);
    return;
  }
};
