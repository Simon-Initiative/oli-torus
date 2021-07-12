import chroma from 'chroma-js';
import React, { useCallback, useEffect, useState } from 'react';
import guid from 'utils/guid';
import Markup from './Markup';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';

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

const TextFlow: React.FC<any> = (props: any) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const initialize = useCallback(async (pModel) => {
    // set defaults

    const initResult = await props.onInit({
      id,
      responses: [],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;
    setState(currentStateSnapshot);

    setReady(true);
  }, []);

  useEffect(() => {
    let pModel;
    let pState;
    if (typeof props?.model === 'string') {
      try {
        pModel = JSON.parse(props.model);
        setModel(pModel);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (typeof props?.state === 'string') {
      try {
        pState = JSON.parse(props.state);
        setState(pState);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (!pModel) {
      return;
    }
    initialize(pModel);
  }, [props]);

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
      NotificationType.HISTORY_NAVIGATION,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`${notificationType.toString()} notification handled [InputText]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            // nothing to do...
            break;
          case NotificationType.HISTORY_NAVIGATION:
            // nothing to do
            break;
          case NotificationType.STATE_CHANGED:
            {
              /* console.log('MUTATE STATE!!!!', {
                payload,
              }); */
              const { mutateChanges: changes } = payload;
              setState({ ...state, ...changes });
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            // nothing to do
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

  const { x = 0, y = 0, width, z = 0, customCssClass, nodes, palette, fontSize } = model;

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
    <div id={props.id} data-janus-type={props.type} className={customCssClass} style={styles}>
      {tree?.map((subtree: MarkupTree) =>
        renderFlow(`textflow-${guid()}`, subtree, styleOverrides, state, fontSize),
      )}
    </div>
  ) : null;
};

export const tagName = 'janus-text-flow';

export default TextFlow;
