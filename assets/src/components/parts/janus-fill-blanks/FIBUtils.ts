export const convertQuillToFIBContetFormat = (nodes: any) => {
  let result = '';

  function traverse(nodeArray: any) {
    nodeArray.forEach((node: any) => {
      if (node.tag === 'text' && node.text) {
        result += node.text + ' ';
      }
      if (Array.isArray(node.children)) {
        traverse(node.children);
      }
    });
  }

  traverse(nodes);
  return result.trim(); // Remove trailing space
};

export const convertFIBContetToQuillFormat = (content: any, elements: any) => {
  let convertedContent = '';
  content?.map((contentItem: { [x: string]: any; insert: any; dropdown: any }) => {
    if (!elements?.length) return;

    const insertList = '';
    let insertEl: any;

    if (contentItem.insert) {
      convertedContent += contentItem.insert;
    } else if (contentItem.dropdown) {
      // get correlating dropdown from `elements`
      insertEl = elements.find((elItem: { key: any }) => elItem.key === contentItem.dropdown);
      if (insertEl) {
        convertedContent += ` {${insertEl.options
          .map((item: any) => {
            if (item.key === insertEl.correct || item.key === insertEl.alternateCorrect) {
              // for correct option, we applly * next to it
              return `"${item.value}"*`;
            } else {
              return `"${item.value}"`;
            }
          })
          .join(', ')}}`;
      }
    } else if (contentItem['text-input']) {
      // get correlating inputText from `elements`
      insertEl = elements.find((elItem: { key: any }) => {
        return elItem.key === contentItem['text-input'];
      });
      if (insertEl) {
        convertedContent += `{"${insertEl.key}"}`;
      }
    }
    return insertList;
  });

  return [
    {
      tag: 'p',
      style: {},
      children: [
        {
          tag: 'span',
          style: { fontSize: '1rem' },
          children: [
            {
              tag: 'text',
              style: {},
              text: convertedContent,
              children: [],
            },
          ],
        },
      ],
    },
  ];
};

type ContentItem = { insert: string } | { 'text-input': string } | { dropdown: string; insert: '' };

type TextInputElement = { correct: string; key: string };
type DropdownElement = {
  correct: string;
  alternateCorrect: string;
  key: string;
  options: { key: string; value: string }[];
};

interface ParsedResult {
  content: ContentItem[];
  elements: (TextInputElement | DropdownElement)[];
}

export const parseQuillToTorusFIB = (input: string): ParsedResult => {
  const content: ContentItem[] = [];
  const textInputElementsMap = new Map<string, TextInputElement>();

  const dropdownElements: DropdownElement[] = [];

  // Regex to catch {...} (non-greedy inside)
  const regex = /{([^{}]+)}/g;

  let lastIndex = 0;
  let match: RegExpExecArray | null;
  let blankCounter = 1;

  while ((match = regex.exec(input)) !== null) {
    const matchStart = match.index;
    const matchEnd = regex.lastIndex;
    const innerContent = match[1]; // inside {}

    // Add preceding text as {insert: ""} if any
    if (matchStart > lastIndex) {
      const text = input.slice(lastIndex, matchStart);
      if (text) {
        content.push({ insert: text });
      }
    }

    // Split by commas and remove quotes/spaces
    const parts = innerContent.split(/\s*,\s*/).map((s) => s.trim().replace(/^"(.*)"$/, '$1')); // remove outer quotes

    if (parts.length === 1) {
      // TEXT-INPUT
      let value = parts[0];
      const isCorrect = value.endsWith('*');
      if (isCorrect) {
        value = value.slice(0, -1); // remove *
      }

      content.push({ 'text-input': value });

      if (!textInputElementsMap.has(value)) {
        textInputElementsMap.set(value, { correct: value, key: value });
      }
    } else {
      // DROPDOWN
      const options: { key: string; value: string }[] = [];
      let correctKey = '';

      parts.forEach((p) => {
        const isCorrect = p.endsWith('*');
        let clean = p;
        if (isCorrect) {
          clean = p.slice(0, -1);
        }
        clean = clean.replace(/^"(.*)"$/, '$1'); // remove quotes if still any
        options.push({ key: clean, value: clean });
        if (isCorrect) {
          correctKey = clean;
        }
      });

      // Fallback to first option if no *
      if (!correctKey && options.length > 0) {
        correctKey = options[0].key;
      }

      const blankKey = `blank${blankCounter++}`;
      content.push({ dropdown: blankKey, insert: '' });

      dropdownElements.push({
        correct: correctKey,
        alternateCorrect: '',
        key: blankKey,
        options,
      });
    }

    lastIndex = matchEnd;
  }

  // Add trailing text
  if (lastIndex < input.length) {
    const remainingText = input.slice(lastIndex);
    if (remainingText) {
      content.push({ insert: remainingText });
    }
  }

  // Combine dropdowns + text-inputs
  const finalElements = [...dropdownElements, ...Array.from(textInputElementsMap.values())];

  return { content, elements: finalElements };
};
