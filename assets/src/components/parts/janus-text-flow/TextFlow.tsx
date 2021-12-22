import { extractExpressionFromText } from 'adaptivity/scripting';
import chroma from 'chroma-js';
import { Environment } from 'janus-script';
import React, { useCallback, useEffect, useState } from 'react';
import guid from 'utils/guid';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { PartComponentProps } from '../types/parts';
import Markup from './Markup';
import { TextFlowModel } from './schema';

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
  if (!node.style) {
    return style;
  }
  if (
    (node.style.styleName === 'Heading' || node.style.styleName === 'Title') &&
    node.children?.length === 1 &&
    child.tag === 'span'
  ) {
    // PMP-526
    style.backgroundColor = '';
  }
  if (node.tag === 'p' && child.tag === 'span' && child.style.color === '#000000') {
    style.color = 'inherit';
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
  env?: Environment,
  expressions?: any,
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
      env={env}
      expressions={expressions}
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
            env,
            expressions,
          );
        })}
    </Markup>
  );
};

const TextFlow: React.FC<PartComponentProps<TextFlowModel>> = (props: any) => {
  const [state, setState] = useState<any>({});
  const [model, setModel] = useState<any>(props.model);
  const [ready, setReady] = useState<boolean>(false);
  const [expressions, setExpressions] = useState<any[]>([]);
  const [scriptEnv, setScriptEnv] = useState<any>();
  const id: string = props.id;

  const handleStylingChanges = () => {
    const styleChanges: any = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    if (height != undefined && props.model.overrideHeight) {
      styleChanges.height = { value: height as number };
    }
    props.onResize({ id: `${id}`, settings: styleChanges });
  };
  const getTextExpressions = (nodes: any) => {
    let optionText = '';
    if (nodes?.text) {
      optionText = extractExpressionFromText(nodes.text);
    } else if (nodes.children) {
      optionText = nodes.children?.map((childrennTree: MarkupTree) => {
        return getTextExpressions(childrennTree || []);
      });
    }
    return typeof optionText === 'object' ? optionText[0] : optionText;
  };
  const initialize = useCallback(async (pModel) => {
    // set defaults
    const pNodes = pModel?.nodes || [];
    let tree: MarkupTree[] = [];
    if (pNodes && typeof pNodes === 'string') {
      tree = JSON.parse(pNodes as string) as MarkupTree[];
    } else if (Array.isArray(pNodes)) {
      tree = pNodes;
    }
    const allExpression = tree?.map((subtree: MarkupTree) => {
      return getTextExpressions(subtree || []);
    });

    const finalExppression = allExpression.filter((expression) => expression);

    const initResult = await props.onInit({
      id,
      responses: [],
      expressions: finalExppression,
    });
    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;
    setState(currentStateSnapshot);

    if (initResult.env) {
      // make a child scope so that any textflow scripts can't affect the parent
      const flowEnv = new Environment(initResult.env);
      setScriptEnv(flowEnv);
    }
    if (initResult?.expressionResult?.length) {
      setExpressions((existingExpression) =>
        existingExpression?.length
          ? [existingExpression, ...initResult.expressionResult]
          : initResult.expressionResult,
      );
    }
    handleStylingChanges();
    setReady(true);
  }, []);

  useEffect(() => {
    initialize(model);
  }, [model]);

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`[TEXTFLOW]: ${notificationType.toString()} notification handled`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            {
              const { snapshot } = payload;
              setState(snapshot);
            }
            break;
          case NotificationType.STATE_CHANGED:
            {
              const { mutateChanges: changes } = payload;
              setState({ ...state, ...changes });
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { snapshot } = payload;
              setState({ ...state, ...snapshot });
            }
            break;
        }
      };
      const unsub = subscribeToNotification(props.notify, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify]);

  const {
    width,
    customCssClass,
    nodes,
    palette,
    fontSize,
    height,
    overrideWidth = true,
    overrideHeight = false,
  } = model;

  const styles: any = {
    wordWrap: 'break-word',
    lineHeight: 'inherit',
  };
  if (overrideWidth) {
    styles.width = width;
  }
  if (overrideHeight) {
    styles.height = height;
  }
  if (fontSize) {
    styles.fontSize = `${fontSize}px`;
  }

  if (palette) {
    if (palette.useHtmlProps) {
      styles.backgroundColor = palette.backgroundColor;
      styles.borderColor = palette.borderColor;
      styles.borderWidth = palette.borderWidth;
      styles.borderStyle = palette.borderStyle;
      styles.borderRadius = palette.borderRadius;
    } else {
      styles.borderWidth = `${palette.lineThickness ? palette.lineThickness + 'px' : 0}`;
      styles.borderRadius = 0;
      styles.borderStyle = palette.lineStyle === 0 ? 'none' : 'solid';
      let borderColor = 'transparent';
      if (palette.lineColor >= 0) {
        borderColor = chroma(palette.lineColor || 0)
          .alpha(palette.lineAlpha || 0)
          .css();
      }
      styles.borderColor = borderColor;

      let bgColor = 'transparent';
      if (palette.fillColor >= 0) {
        bgColor = chroma(palette.fillColor || 0)
          .alpha(palette.fillAlpha || 0)
          .css();
      }
      styles.backgroundColor = bgColor;
    }
  }

  // TODO: preprocess model to find required variables and/or expressions
  // using onInit to wait for initial state to be sent, and hold rendering
  // until isReady (and also then fire onReady)
  // send pre-calculated map of required values to Markup

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

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

  return ready ? (
    <div data-janus-type={tagName} style={styles}>
      {tree?.map((subtree: MarkupTree) =>
        renderFlow(
          `textflow-${guid()}`,
          subtree,
          styleOverrides,
          state,
          fontSize,
          undefined,
          scriptEnv,
          expressions,
        ),
      )}
    </div>
  ) : null;
};

export const tagName = 'janus-text-flow';

export default TextFlow;
