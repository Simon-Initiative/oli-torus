import { _Lexer } from 'Lexer';
import { Token, Tokens } from 'Tokens';
import { marked } from 'marked';
import { Element, Node } from 'slate';
import { Model } from 'data/content/model/elements/factories';
import {
  AllModelElements,
  ListChildren,
  ListItem,
  OrderedList,
  TableRow,
  UnorderedList,
} from 'data/content/model/elements/types';
import { FormattedText } from 'data/content/model/text';
import guid from 'utils/guid';

interface SerializationContext {
  marks: {
    strong: boolean;
    em: boolean;
    underline: boolean;
    strikethrough: boolean;
  };
}

const defaultContext: SerializationContext = {
  marks: {
    strong: false,
    em: false,
    underline: false,
    strikethrough: false,
  },
};

export const createLexer = (): _Lexer => {
  const lexer = new marked.Lexer({
    gfm: true,
  });

  return lexer;
};

const serializeTokenToText = (
  token: Tokens.Text,
  context: SerializationContext,
): FormattedText[] | null => {
  const activeMarks = Object.keys(context.marks).filter(
    (key) => context.marks[key as keyof typeof context.marks],
  ) as (keyof typeof context.marks)[];

  const marks = activeMarks.reduce(
    (acc, mark) => ({
      ...acc,
      [mark]: true,
    }),
    {},
  );

  return [{ text: token.text, ...marks }];
};

const serializeToken =
  (context: SerializationContext) =>
  (token: Token): (FormattedText | AllModelElements)[] | null => {
    switch (token.type) {
      case 'text':
        return serializeTokenToText(token as Tokens.Text, context);
      case 'paragraph':
        return [{ type: 'p', id: guid(), children: serializeTokens(token.tokens, context) as any }];
      case 'heading':
        const depth = Math.max(1, Math.min(token.depth || 1, 6)) as 1 | 2 | 3 | 4 | 5 | 6;
        return [
          {
            type: `h${depth}`,
            id: guid(),
            children: serializeTokens(token.tokens, context) as any,
          },
        ];
      case 'strong':
        const strongContext = { ...context, marks: { ...context.marks, strong: true } };
        return serializeTokens(token.tokens, strongContext);
      case 'em':
        return serializeTokens(token.tokens, { ...context, marks: { ...context.marks, em: true } });
      case 'underline':
        return serializeTokens(token.tokens, {
          ...context,
          marks: { ...context.marks, underline: true },
        });
      case 'codespan':
        return [{ code: true, text: token.text }];
      case 'code':
        return serializeCode(token as Tokens.Code, context);
      case 'del':
        return serializeTokens(token.tokens, {
          ...context,
          marks: { ...context.marks, strikethrough: true },
        });
      case 'table':
        return serializeTable(token as Tokens.Table, context);
      case 'list':
        return serializeList(token as Tokens.List, context);
      case 'image':
        return serializeImage(token as Tokens.Image, context);
      case 'space':
        return null;
    }

    // Unknown token, process children.
    if ('tokens' in token && token.tokens) {
      console.warn('Unknown token with .tokens', token);
      return serializeTokens(token.tokens, context);
    }

    console.warn('Unknown token', token);
    return null;
  };

const serializeImage = (token: Tokens.Image, context: SerializationContext): AllModelElements[] => {
  return [Model.image(token.href, !token.text ? undefined : token.text)];
};

const serializeCode = (
  token: Tokens.Code,
  context: SerializationContext,
): (FormattedText | AllModelElements)[] => {
  const codeText = token.text;
  const code = Model.code(codeText);
  code.language = token.lang || 'Text';
  return [code];
};

const serializeTokens = (
  tokens: Token[] | undefined,
  context: SerializationContext,
): (FormattedText | AllModelElements)[] => {
  if (!tokens) return [];
  return tokens.map(serializeToken(context)).filter(isNotNull).flat();
};

const isNotNull = <TValue>(value: TValue | null | undefined): value is TValue => {
  return value !== null && value !== undefined;
};

const wrapWithParagraph = (elements: (FormattedText | AllModelElements)[]): AllModelElements[] => {
  return elements.map((element) => {
    if ('text' in element) {
      return Model.p([element]);
    }
    return element;
  });
};

const isList = (n: Node): n is UnorderedList | OrderedList =>
  Element.isElement(n) && (n.type === 'ul' || n.type === 'ol');

const serializeList = (token: Tokens.List, context: SerializationContext): AllModelElements[] => {
  const items = token.items.map((item) => {
    if (item.type === 'list_item') {
      const children = serializeTokens(item.tokens, context) as any[];
      return Model.li(children);
    }
    return serializeTokens(item.tokens, context);
  });

  const itemsWithSubLists: ListChildren = [];
  /*
    The markdown lexer will put sub-lists inside list items.
    We want them next to list items.
  */
  items.forEach((item) => {
    const subLists = 'children' in item && (item.children.filter(isList) as ListChildren);
    const nonSubLists =
      'children' in item && (item.children.filter((n) => !isList(n)) as ListItem['children']);
    if (subLists) {
      nonSubLists &&
        itemsWithSubLists.push(Model.li(wrapWithParagraph(nonSubLists) as ListItem['children']));
      itemsWithSubLists.push(...subLists);
    } else {
      if ('type' in item && item.type === 'li' && item.children) {
        item.children = wrapWithParagraph(item.children as any) as any;
      }
      itemsWithSubLists.push(item as ListItem);
    }
  });

  const list = token.ordered ? Model.ol(itemsWithSubLists) : Model.ul(itemsWithSubLists);
  return [list];
};

const serializeTable = (token: Tokens.Table, context: SerializationContext): AllModelElements[] => {
  const rows: TableRow[] = [];

  if (token.header && token.header.length > 0) {
    rows.push(
      Model.tr(
        token.header.map((cell) => ({
          type: 'th',
          id: guid(),
          children: wrapWithParagraph(serializeTokens(cell.tokens, context)) as any,
        })),
      ),
    );
  }

  token.rows.forEach((row) => {
    rows.push(
      Model.tr(
        row.map((cell) => ({
          type: 'td',
          id: guid(),
          children: wrapWithParagraph(serializeTokens(cell.tokens, context)) as any,
        })),
      ),
    );
  });

  return [Model.table(rows)];
};

export const serializeMarkdown = (markdown: string): (FormattedText | AllModelElements)[] => {
  const lexer = createLexer();
  const tokens = lexer.lex(markdown);
  return serializeTokens(tokens, defaultContext);
};

/*
Sample lexer.lex() output:
[
  {
    "type": "heading",
    "raw": "# H1 Heading\n\n",
    "depth": 1,
    "text": "H1 Heading",
    "tokens": [
      {
        "type": "text",
        "raw": "H1 Heading",
        "text": "H1 Heading"
      }
    ]
  },
  {
    "type": "heading",
    "raw": "## H2 Heading\n\n",
    "depth": 2,
    "text": "H2 Heading",
    "tokens": [
      {
        "type": "text",
        "raw": "H2 Heading",
        "text": "H2 Heading"
      }
    ]
  },
  {
    "type": "paragraph",
    "raw": "Here is a paragraph of plain text.   Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text. ",
    "text": "Here is a paragraph of plain text.   Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text. ",
    "tokens": [
      {
        "type": "text",
        "raw": "Here is a paragraph of plain text.   Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text. ",
        "text": "Here is a paragraph of plain text.   Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text.  Here is a paragraph of plain text. "
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n"
  },
  {
    "type": "paragraph",
    "raw": "Here is a paragraph of formatted text with **bold** *italic* code  __underline__ ~~strikethrough~~ superscript subscript ",
    "text": "Here is a paragraph of formatted text with **bold** *italic* code  __underline__ ~~strikethrough~~ superscript subscript ",
    "tokens": [
      {
        "type": "text",
        "raw": "Here is a paragraph of formatted text with ",
        "text": "Here is a paragraph of formatted text with "
      },
      {
        "type": "strong",
        "raw": "**bold**",
        "text": "bold",
        "tokens": [
          {
            "type": "text",
            "raw": "bold",
            "text": "bold"
          }
        ]
      },
      {
        "type": "text",
        "raw": " ",
        "text": " "
      },
      {
        "type": "em",
        "raw": "*italic*",
        "text": "italic",
        "tokens": [
          {
            "type": "text",
            "raw": "italic",
            "text": "italic"
          }
        ]
      },
      {
        "type": "text",
        "raw": " code  ",
        "text": " code  "
      },
      {
        "type": "strong",
        "raw": "__underline__",
        "text": "underline",
        "tokens": [
          {
            "type": "text",
            "raw": "underline",
            "text": "underline"
          }
        ]
      },
      {
        "type": "text",
        "raw": " ~~strikethrough~~ superscript subscript ",
        "text": " ~~strikethrough~~ superscript subscript "
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n"
  },
  {
    "type": "paragraph",
    "raw": "This one has a [link ](http://www.cnn.com/)inside it.",
    "text": "This one has a [link ](http://www.cnn.com/)inside it.",
    "tokens": [
      {
        "type": "text",
        "raw": "This one has a ",
        "text": "This one has a "
      },
      {
        "type": "link",
        "raw": "[link ](http://www.cnn.com/)",
        "href": "http://www.cnn.com/",
        "title": null,
        "text": "link ",
        "tokens": [
          {
            "type": "text",
            "raw": "link ",
            "text": "link "
          }
        ]
      },
      {
        "type": "text",
        "raw": "inside it.",
        "text": "inside it."
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n"
  },
  {
    "type": "paragraph",
    "raw": "Following this line is an empty paragraph.",
    "text": "Following this line is an empty paragraph.",
    "tokens": [
      {
        "type": "text",
        "raw": "Following this line is an empty paragraph.",
        "text": "Following this line is an empty paragraph."
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n\n\n"
  },
  {
    "type": "paragraph",
    "raw": "The empty paragraph was before this line.",
    "text": "The empty paragraph was before this line.",
    "tokens": [
      {
        "type": "text",
        "raw": "The empty paragraph was before this line.",
        "text": "The empty paragraph was before this line."
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n"
  },
  {
    "type": "list",
    "raw": "- Unordered list\n- with three\n- items in it",
    "ordered": false,
    "start": "",
    "loose": false,
    "items": [
      {
        "type": "list_item",
        "raw": "- Unordered list\n",
        "task": false,
        "loose": false,
        "text": "Unordered list",
        "tokens": [
          {
            "type": "text",
            "raw": "Unordered list",
            "text": "Unordered list",
            "tokens": [
              {
                "type": "text",
                "raw": "Unordered list",
                "text": "Unordered list"
              }
            ]
          }
        ]
      },
      {
        "type": "list_item",
        "raw": "- with three\n",
        "task": false,
        "loose": false,
        "text": "with three",
        "tokens": [
          {
            "type": "text",
            "raw": "with three",
            "text": "with three",
            "tokens": [
              {
                "type": "text",
                "raw": "with three",
                "text": "with three"
              }
            ]
          }
        ]
      },
      {
        "type": "list_item",
        "raw": "- items in it",
        "task": false,
        "loose": false,
        "text": "items in it",
        "tokens": [
          {
            "type": "text",
            "raw": "items in it",
            "text": "items in it",
            "tokens": [
              {
                "type": "text",
                "raw": "items in it",
                "text": "items in it"
              }
            ]
          }
        ]
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n\n\n"
  },
  {
    "type": "list",
    "raw": "1. Ordered list\n2. With three items\n3. in it",
    "ordered": true,
    "start": 1,
    "loose": false,
    "items": [
      {
        "type": "list_item",
        "raw": "1. Ordered list\n",
        "task": false,
        "loose": false,
        "text": "Ordered list",
        "tokens": [
          {
            "type": "text",
            "raw": "Ordered list",
            "text": "Ordered list",
            "tokens": [
              {
                "type": "text",
                "raw": "Ordered list",
                "text": "Ordered list"
              }
            ]
          }
        ]
      },
      {
        "type": "list_item",
        "raw": "2. With three items\n",
        "task": false,
        "loose": false,
        "text": "With three items",
        "tokens": [
          {
            "type": "text",
            "raw": "With three items",
            "text": "With three items",
            "tokens": [
              {
                "type": "text",
                "raw": "With three items",
                "text": "With three items"
              }
            ]
          }
        ]
      },
      {
        "type": "list_item",
        "raw": "3. in it",
        "task": false,
        "loose": false,
        "text": "in it",
        "tokens": [
          {
            "type": "text",
            "raw": "in it",
            "text": "in it",
            "tokens": [
              {
                "type": "text",
                "raw": "in it",
                "text": "in it"
              }
            ]
          }
        ]
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n\n\n"
  },
  {
    "type": "list",
    "raw": "- Unordered list with a nested ordered list.\n  1. Two items in\n  2. the sub list\n- Finally an unordered item",
    "ordered": false,
    "start": "",
    "loose": false,
    "items": [
      {
        "type": "list_item",
        "raw": "- Unordered list with a nested ordered list.\n  1. Two items in\n  2. the sub list\n",
        "task": false,
        "loose": false,
        "text": "Unordered list with a nested ordered list.\n1. Two items in\n2. the sub list",
        "tokens": [
          {
            "type": "text",
            "raw": "Unordered list with a nested ordered list.\n",
            "text": "Unordered list with a nested ordered list.",
            "tokens": [
              {
                "type": "text",
                "raw": "Unordered list with a nested ordered list.",
                "text": "Unordered list with a nested ordered list."
              }
            ]
          },
          {
            "type": "list",
            "raw": "1. Two items in\n2. the sub list",
            "ordered": true,
            "start": 1,
            "loose": false,
            "items": [
              {
                "type": "list_item",
                "raw": "1. Two items in\n",
                "task": false,
                "loose": false,
                "text": "Two items in",
                "tokens": [
                  {
                    "type": "text",
                    "raw": "Two items in",
                    "text": "Two items in",
                    "tokens": [
                      {
                        "type": "text",
                        "raw": "Two items in",
                        "text": "Two items in"
                      }
                    ]
                  }
                ]
              },
              {
                "type": "list_item",
                "raw": "2. the sub list",
                "task": false,
                "loose": false,
                "text": "the sub list",
                "tokens": [
                  {
                    "type": "text",
                    "raw": "the sub list",
                    "text": "the sub list",
                    "tokens": [
                      {
                        "type": "text",
                        "raw": "the sub list",
                        "text": "the sub list"
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      },
      {
        "type": "list_item",
        "raw": "- Finally an unordered item",
        "task": false,
        "loose": false,
        "text": "Finally an unordered item",
        "tokens": [
          {
            "type": "text",
            "raw": "Finally an unordered item",
            "text": "Finally an unordered item",
            "tokens": [
              {
                "type": "text",
                "raw": "Finally an unordered item",
                "text": "Finally an unordered item"
              }
            ]
          }
        ]
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n\n\n"
  },
  {
    "type": "paragraph",
    "raw": "There is an image below this.",
    "text": "There is an image below this.",
    "tokens": [
      {
        "type": "text",
        "raw": "There is an image below this.",
        "text": "There is an image below this."
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n"
  },
  {
    "type": "paragraph",
    "raw": "![iThere is a polar bear in this image\n](https://torus-media-dev.s3.amazonaws.com/media/EE/EE9E09624663B49019B3999E0E501487/polar-bear-2.jpg)",
    "text": "![iThere is a polar bear in this image\n](https://torus-media-dev.s3.amazonaws.com/media/EE/EE9E09624663B49019B3999E0E501487/polar-bear-2.jpg)",
    "tokens": [
      {
        "type": "image",
        "raw": "![iThere is a polar bear in this image\n](https://torus-media-dev.s3.amazonaws.com/media/EE/EE9E09624663B49019B3999E0E501487/polar-bear-2.jpg)",
        "href": "https://torus-media-dev.s3.amazonaws.com/media/EE/EE9E09624663B49019B3999E0E501487/polar-bear-2.jpg",
        "title": null,
        "text": "iThere is a polar bear in this image\n"
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n\n\n"
  },
  {
    "type": "paragraph",
    "raw": "This",
    "text": "This",
    "tokens": [
      {
        "type": "text",
        "raw": "This",
        "text": "This"
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n"
  },
  {
    "type": "paragraph",
    "raw": "is",
    "text": "is",
    "tokens": [
      {
        "type": "text",
        "raw": "is",
        "text": "is"
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n"
  },
  {
    "type": "paragraph",
    "raw": "a",
    "text": "a",
    "tokens": [
      {
        "type": "text",
        "raw": "a",
        "text": "a"
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n"
  },
  {
    "type": "paragraph",
    "raw": "table",
    "text": "table",
    "tokens": [
      {
        "type": "text",
        "raw": "table",
        "text": "table"
      }
    ]
  },
  {
    "type": "space",
    "raw": "\n\n\n\n"
  }
]

*/
