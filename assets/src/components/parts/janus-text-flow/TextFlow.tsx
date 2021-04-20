import chroma from 'chroma-js';
import React, { useEffect } from 'react';
import guid from 'utils/guid';
import Markup from './Markup';

export interface MarkupTree {
  tag: string;
  href?: string;
  src?: string;
  target?: string;
  style?: any;
  text?: string;
  children?: MarkupTree[];
}

export const getStylesToOverwrite = (node: MarkupTree, child: MarkupTree, fontSize?: any) => {
  const style: any = {};
  if (
    (node.style.styleName === 'Heading' || node.style.styleName === 'Title') &&
    node.children?.length === 1 &&
    child.tag === 'span'
  ) {
    // PMP-526
    style.backgroundColor = '';
  }
  if (!(child.style && child.style.fontSize) && fontSize) {
    style.fontSize = `${fontSize}px`;
  }
  return style;
};

export const renderFlow = (
  key: string,
  treeNode: MarkupTree,
  styleOverrides: any,
  state: any[] = [],
  fontSize?: any,
  specialTag?: string,
) => {
  // clone styles
  const styles: any = { ...treeNode.style };
  // loop override styles
  Object.keys(styleOverrides).forEach((s) => {
    // override styles
    styles[s] = styleOverrides[s];
  });
  // if style have 'baselineShift = superscript' or 'baselineShift = subscript'
  // need to handle them separately
  let customTag = '';
  if (styles?.baselineShift === 'superscript') {
    customTag = 'sup';
  } else if (styles?.baselineShift === 'subscript') {
    customTag = 'sub';
  }
  return (
    <Markup
      key={key}
      tag={specialTag || treeNode.tag}
      href={treeNode.href}
      src={treeNode.src}
      target={treeNode.target}
      style={styles}
      text={treeNode.text}
      state={state}
    >
      {treeNode.children &&
        treeNode.children.map((child, index) => {
          return renderFlow(
            `${key}_${index}`,
            child,
            getStylesToOverwrite(treeNode, child, fontSize),
            state,
            fontSize,
            customTag,
          );
        })}
    </Markup>
  );
};

const TextFlow: React.FC<any> = (props) => {
  const { x = 0, y = 0, width, z = 0, customCssClass, nodes, palette, fontSize } = props.model;
  const styles: any = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    zIndex: z,
    wordWrap: 'break-word',
  };
  if (fontSize) {
    styles.fontSize = `${fontSize}px`;
  }
  if (palette) {
    styles.borderWidth = `${palette?.lineThickness ? palette?.lineThickness + 'px' : '1px'}`;
    (styles.borderStyle = 'solid'),
      (styles.borderColor = `rgba(${
        palette?.lineColor || palette?.lineColor === 0
          ? chroma(palette?.lineColor).rgb().join(',')
          : '255, 255, 255'
      },${palette?.lineAlpha})`),
      (styles.backgroundColor = `rgba(${
        palette?.fillColor || palette?.fillColor === 0
          ? chroma(palette?.fillColor).rgb().join(',')
          : '255, 255, 255'
      },${palette?.fillAlpha})`);
  }
  useEffect(() => {
    // all activities *must* emit onReady
    // console.log('TEXTFLOW ONE TIME', props.id);

    props.onReady({ id: `${props.id}` });
  }, []);

  // due to custom elements, objects will be JSON
  let tree: MarkupTree[] = [];
  if (nodes && typeof nodes === 'string') {
    tree = JSON.parse(nodes as string) as MarkupTree[];
  } else if (Array.isArray(nodes)) {
    tree = nodes;
  }
  const styleOverrides: any = {};
  if (width) {
    styleOverrides.width = width;
  }
  if (fontSize) {
    styleOverrides.fontSize = `${fontSize}px`;
  }

  return (
    <div id={props.id} data-janus-type={props.type} className={customCssClass} style={styles}>
      {tree?.map((subtree: MarkupTree) =>
        renderFlow(`textflow-${guid()}`, subtree, styleOverrides, props.state, fontSize),
      )}
    </div>
  );
};

export const tagName = 'janus-text-flow';

// TODO: restore web component

export default TextFlow;
