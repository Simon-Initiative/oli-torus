export const convertQuillNodesToText = (nodes: any[]): string => {
  let textContent = '';

  const traverseNodes = (nodeArray: any[]) => {
    nodeArray.forEach((node) => {
      if (node.tag === 'text' && node.text) {
        textContent += node.text + ' ';
      }
      if (Array.isArray(node.children)) {
        traverseNodes(node.children);
      }
    });
  };

  traverseNodes(nodes);
  return textContent.trim();
};

export const convertFIBContentToQuillNodes = (contentItems: any[], blanks: any[]) => {
  let finalText = '';

  contentItems?.forEach((item) => {
    if (!blanks?.length) return;

    if (item.insert) {
      finalText += item.insert;
    } else if (item.dropdown) {
      const matchingDropdown = blanks.find((b) => b.key === item.dropdown);

      if (matchingDropdown) {
        finalText += ` {${matchingDropdown.options
          .map((opt: any) => {
            const isCorrect =
              opt.key === matchingDropdown.correct || opt.key === matchingDropdown.alternateCorrect;
            return `"${opt.value}"${isCorrect ? '*' : ''}`;
          })
          .join(', ')}}`;
      }
    } else if (item['text-input']) {
      const matchingInput = blanks.find((b) => b.key === item['text-input']);

      if (matchingInput) {
        finalText += `{"${matchingInput.key}"}`;
      }
    }
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
              text: finalText,
              children: [],
            },
          ],
        },
      ],
    },
  ];
};

type FIBContentItem =
  | { insert: string }
  | { 'text-input': string }
  | { dropdown: string; insert: '' };

type TextInputBlank = { correct: string; key: string };
type DropdownBlank = {
  correct: string;
  alternateCorrect: string;
  key: string;
  options: { key: string; value: string }[];
};

interface ParsedFIBResult {
  content: FIBContentItem[];
  elements: (TextInputBlank | DropdownBlank)[];
}

export const parseTextToFIBStructure = (inputText: string): ParsedFIBResult => {
  const contentItems: FIBContentItem[] = [];
  const textInputs = new Map<string, TextInputBlank>();
  const dropdowns: DropdownBlank[] = [];
  const placeholderRegex = /{([^{}]+)}/g;
  let lastProcessedIndex = 0;
  let match: RegExpExecArray | null;
  let blankCounter = 1;

  while ((match = placeholderRegex.exec(inputText)) !== null) {
    const matchStart = match.index;
    const matchEnd = placeholderRegex.lastIndex;
    const placeholderContent = match[1];

    if (matchStart > lastProcessedIndex) {
      const plainText = inputText.slice(lastProcessedIndex, matchStart);
      if (plainText) contentItems.push({ insert: plainText });
    }

    const parts = placeholderContent
      .split(/\s*,\s*/)
      .map((s) => s.trim().replace(/^"(.*)"$/, '$1'));

    if (parts.length === 1) {
      let value = parts[0];
      const isCorrect = value.endsWith('*');
      if (isCorrect) value = value.slice(0, -1);

      contentItems.push({ 'text-input': value });

      if (!textInputs.has(value)) {
        textInputs.set(value, { correct: value, key: value });
      }
    } else {
      const options: { key: string; value: string }[] = [];
      let correctKey = '';

      parts.forEach((option) => {
        const isCorrect = option.endsWith('*');
        let cleaned = isCorrect ? option.slice(0, -1) : option;
        cleaned = cleaned.replace(/^"(.*)"$/, '$1');
        options.push({ key: cleaned, value: cleaned });
        if (isCorrect) correctKey = cleaned;
      });

      if (!correctKey && options.length > 0) {
        correctKey = options[0].key;
      }

      const dropdownKey = `blank${blankCounter++}`;
      contentItems.push({ dropdown: dropdownKey, insert: '' });

      dropdowns.push({
        correct: correctKey,
        alternateCorrect: '',
        key: dropdownKey,
        options,
      });
    }

    lastProcessedIndex = matchEnd;
  }

  if (lastProcessedIndex < inputText.length) {
    const remaining = inputText.slice(lastProcessedIndex);
    if (remaining) contentItems.push({ insert: remaining });
  }

  const elements = [...dropdowns, ...Array.from(textInputs.values())];
  console.log({ contentItems, elements });
  return { content: contentItems, elements };
};

type FIBElement = DropdownBlank | TextInputBlank;

interface NormalizedBlank {
  key: string;
  options: string[];
  type: 'dropdown' | 'input';
  correct: string;
}

export const normalizeBlanks = (elements: FIBElement[]): NormalizedBlank[] => {
  return elements.map((el, idx) => {
    if ('options' in el) {
      return {
        key: `blank ${idx + 1}`,
        options: el.options.map((opt) => opt.value),
        type: 'dropdown',
        correct: el.correct,
      };
    } else {
      return {
        key: `blank ${idx + 1}`,
        options: [el.correct],
        type: 'input',
        correct: 'true',
      };
    }
  });
};
