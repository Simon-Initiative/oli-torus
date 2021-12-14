var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import chroma from 'chroma-js';
import { Environment } from 'janus-script';
import React, { useCallback, useEffect, useState } from 'react';
import guid from 'utils/guid';
import { NotificationType, subscribeToNotification, } from '../../../apps/delivery/components/NotificationContext';
import Markup from './Markup';
export const getStylesToOverwrite = (node, child, fontSize) => {
    var _a;
    const style = {};
    if (!node.style) {
        return style;
    }
    if ((node.style.styleName === 'Heading' || node.style.styleName === 'Title') &&
        ((_a = node.children) === null || _a === void 0 ? void 0 : _a.length) === 1 &&
        child.tag === 'span') {
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
export const renderFlow = (key, treeNode, styleOverrides, state = [], fontSize, specialTag, env) => {
    // clone styles
    const styles = Object.assign({}, treeNode.style);
    // loop override styles
    Object.keys(styleOverrides).forEach((s) => {
        // override styles
        styles[s] = styleOverrides[s];
    });
    // if style have 'baselineShift = superscript' or 'baselineShift = subscript'
    // need to handle them separately
    let customTag = '';
    if ((styles === null || styles === void 0 ? void 0 : styles.baselineShift) === 'superscript') {
        customTag = 'sup';
    }
    else if ((styles === null || styles === void 0 ? void 0 : styles.baselineShift) === 'subscript') {
        customTag = 'sub';
    }
    return (<Markup key={key} tag={specialTag || treeNode.tag} href={treeNode.href} src={treeNode.src} target={treeNode.target} style={styles} text={treeNode.text} state={state} env={env}>
      {treeNode.children &&
            treeNode.children.map((child, index) => {
                return renderFlow(`${key}_${index}`, child, getStylesToOverwrite(treeNode, child, fontSize), state, fontSize, customTag, env);
            })}
    </Markup>);
};
const TextFlow = (props) => {
    const [state, setState] = useState({});
    const [model, setModel] = useState(props.model);
    const [ready, setReady] = useState(false);
    const [scriptEnv, setScriptEnv] = useState();
    const id = props.id;
    const handleStylingChanges = () => {
        const styleChanges = {};
        if (width !== undefined) {
            styleChanges.width = { value: width };
        }
        if (height != undefined && props.model.overrideHeight) {
            styleChanges.height = { value: height };
        }
        props.onResize({ id: `${id}`, settings: styleChanges });
    };
    const initialize = useCallback((pModel) => __awaiter(void 0, void 0, void 0, function* () {
        // set defaults
        const initResult = yield props.onInit({
            id,
            responses: [],
        });
        // result of init has a state snapshot with latest (init state applied)
        const currentStateSnapshot = initResult.snapshot;
        setState(currentStateSnapshot);
        if (initResult.env) {
            // make a child scope so that any textflow scripts can't affect the parent
            const flowEnv = new Environment(initResult.env);
            setScriptEnv(flowEnv);
        }
        handleStylingChanges();
        setReady(true);
    }), []);
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
        const notifications = notificationsHandled.map((notificationType) => {
            const handler = (payload) => {
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
                            setState(Object.assign(Object.assign({}, state), changes));
                        }
                        break;
                    case NotificationType.CONTEXT_CHANGED:
                        {
                            const { snapshot } = payload;
                            setState(Object.assign(Object.assign({}, state), snapshot));
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
    const { width, customCssClass, nodes, palette, fontSize, height, overrideWidth = true, overrideHeight = false, } = model;
    const styles = {
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
        }
        else {
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
    let tree = [];
    if (nodes && typeof nodes === 'string') {
        tree = JSON.parse(nodes);
    }
    else if (Array.isArray(nodes)) {
        tree = nodes;
    }
    const styleOverrides = {};
    if (width) {
        styleOverrides.width = width;
    }
    if (fontSize) {
        styleOverrides.fontSize = `${fontSize}px`;
    }
    return ready ? (<div data-janus-type={tagName} style={styles}>
      {tree === null || tree === void 0 ? void 0 : tree.map((subtree) => renderFlow(`textflow-${guid()}`, subtree, styleOverrides, state, fontSize, undefined, scriptEnv))}
    </div>) : null;
};
export const tagName = 'janus-text-flow';
export default TextFlow;
//# sourceMappingURL=TextFlow.jsx.map