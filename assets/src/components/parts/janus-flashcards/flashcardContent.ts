import { MarkupTree } from '../janus-text-flow/TextFlow';

export const plainTextToDefaultNodes = (text: string): MarkupTree[] => [
  {
    tag: 'p',
    style: {},
    children: [
      {
        tag: 'span',
        style: { backgroudColor: 'transparent', color: 'inherit', fontSize: '16px' },
        children: [{ tag: 'text', text: text || ' ', children: [] }],
      },
    ],
  },
];

export const parseNodes = (nodes: unknown): MarkupTree[] => {
  if (!nodes) return [];
  if (typeof nodes === 'string') {
    try {
      return JSON.parse(nodes) as MarkupTree[];
    } catch {
      return [];
    }
  }
  return Array.isArray(nodes) ? (nodes as MarkupTree[]) : [];
};

export const getFaceNodes = (
  card: { frontNodes?: MarkupTree[]; backNodes?: MarkupTree[] },
  side: 'front' | 'back',
): MarkupTree[] => {
  const nodes = side === 'front' ? card.frontNodes : card.backNodes;
  const parsed = parseNodes(nodes);

  if (parsed.length > 0) return parsed;
  return plainTextToDefaultNodes('');
};

export const isimageOnlyNodes = (nodes: MarkupTree[]): boolean => {
  const hasImg = JSON.stringify(nodes).includes('"tag":"img"');
  const text = JSON.stringify(nodes).replace(/<[^>]+>/g, '');
  return hasImg && !/\btext":"[^"]{2,}/.test(text);
};

export const stripFlashcardImageDimensions = (nodes: MarkupTree[]): MarkupTree[] =>
  nodes.map((node) => {
    const children = node.children ? stripFlashcardImageDimensions(node.children) : node.children;

    if (node.tag !== 'img' || !node.style) {
      return children === node.children ? node : { ...node, children };
    }

    const { width: _width, height: _height, ...style } = node.style;

    return {
      ...node,
      style,
      children,
    };
  });
