var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { NotificationType, subscribeToNotification, } from 'apps/delivery/components/NotificationContext';
import chroma from 'chroma-js';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { clone, parseBoolean } from 'utils/common';
import guid from 'utils/guid';
import Markup from './Markup';
import { registerEditor, tagName as quillEditorTagName } from './QuillEditor';
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
export const renderFlow = (key, treeNode, styleOverrides, state = {}, fontSize, specialTag) => {
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
    // disable hyperlinks and replace with a faux hyperlink
    // because we don't want to navigate in authoring mode
    if (treeNode.tag === 'a') {
        specialTag = 'span';
        styles.color = '#0000ff';
        styles.textDecoration = 'underline';
    }
    return (<Markup key={key} tag={specialTag || treeNode.tag} href={treeNode.href} src={treeNode.src} target={treeNode.target} style={styles} text={treeNode.text} state={state} customCssClass={treeNode.customCssClass} displayRawText={true}>
      {treeNode.children &&
            treeNode.children.map((child, index) => {
                return renderFlow(`${key}_${index}`, child, getStylesToOverwrite(treeNode, child, fontSize), state, fontSize, customTag);
            })}
    </Markup>);
};
// eslint-disable-next-line react/display-name
const Editor = React.memo(({ html, tree, portal }) => {
    const quillProps = {};
    if (tree) {
        quillProps.tree = JSON.stringify(tree);
    }
    if (html) {
        quillProps.html = html;
    }
    /* console.log('E RERENDER', { html, tree, portal }); */
    const E = () => (<div style={{ padding: 20 }}>{React.createElement(quillEditorTagName, quillProps)}</div>);
    return portal && ReactDOM.createPortal(<E />, portal);
});
const TextFlowAuthor = (props) => {
    var _a;
    const { configuremode, onConfigure, onCancelConfigure, onSaveConfigure } = props;
    const [ready, setReady] = useState(false);
    const id = props.id;
    const [inConfigureMode, setInConfigureMode] = useState(parseBoolean(configuremode));
    const htmlPreviewRef = useRef(null);
    const [htmlPreview, setHtmlPreview] = useState('');
    const [model, setModel] = useState(props.model);
    const [textNodes, setTextNodes] = useState(props.model.nodes);
    useEffect(() => {
        setModel(props.model);
    }, [props.model]);
    useEffect(() => {
        setInConfigureMode(parseBoolean(configuremode));
    }, [configuremode]);
    const initialize = useCallback((pModel) => __awaiter(void 0, void 0, void 0, function* () {
        setReady(true);
    }), []);
    useEffect(() => {
        initialize(model);
    }, []);
    const { x = 0, y = 0, width, z = 0, customCssClass, nodes, palette, fontSize, height, overrideWidth = true, overrideHeight = false, } = model;
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
    useEffect(() => {
        registerEditor();
    }, []);
    useEffect(() => {
        const handleEditorSave = (e) => {
            if (!inConfigureMode) {
                return;
            } // not mine
            const { payload, callback } = e.detail;
            // console.log('TF EDITOR SAVE', { payload, callback, props });
            const modelClone = clone(model);
            modelClone.nodes = payload;
            // optimistic update
            setModel(modelClone);
            onSaveConfigure({
                id,
                snapshot: modelClone,
            });
        };
        const handleEditorCancel = () => {
            if (!inConfigureMode) {
                return;
            } // not mine
            // console.log('TF EDITOR CANCEL');
            setInConfigureMode(false);
            onCancelConfigure({ id });
        };
        const handleEditorChange = (e) => {
            if (!inConfigureMode) {
                return;
            } // not mine
            const { payload, callback } = e.detail;
            // console.log('TF EDITOR CHANGE', { payload, callback });
            setTextNodes(payload.value);
        };
        if (inConfigureMode) {
            document.addEventListener(`${quillEditorTagName}-change`, handleEditorChange);
            document.addEventListener(`${quillEditorTagName}-save`, handleEditorSave);
            document.addEventListener(`${quillEditorTagName}-cancel`, handleEditorCancel);
        }
        return () => {
            document.removeEventListener(`${quillEditorTagName}-change`, handleEditorChange);
            document.removeEventListener(`${quillEditorTagName}-save`, handleEditorSave);
            document.removeEventListener(`${quillEditorTagName}-cancel`, handleEditorCancel);
        };
    }, [ready, inConfigureMode, model]);
    const handleNotificationSave = useCallback(() => __awaiter(void 0, void 0, void 0, function* () {
        /* console.log('TF:NOTIFYSAVE', { id, model, textNodes }); */
        const modelClone = clone(model);
        modelClone.nodes = textNodes;
        yield onSaveConfigure({ id, snapshot: modelClone });
        setInConfigureMode(false);
    }), [model, textNodes]);
    useEffect(() => {
        if (!props.notify) {
            return;
        }
        const notificationsHandled = [
            NotificationType.CONFIGURE,
            NotificationType.CONFIGURE_SAVE,
            NotificationType.CONFIGURE_CANCEL,
        ];
        const notifications = notificationsHandled.map((notificationType) => {
            const handler = (payload) => {
                /* console.log(`${notificationType.toString()} notification event [PopupAuthor]`, payload); */
                if (!payload) {
                    // if we don't have anything, we won't even have an id to know who it's for
                    // for these events we need something, it's not for *all* of them
                    return;
                }
                switch (notificationType) {
                    case NotificationType.CONFIGURE:
                        {
                            const { partId, configure } = payload;
                            if (partId === id) {
                                /* console.log('TF:NotificationType.CONFIGURE', { partId, configure }); */
                                // if it's not us, then we shouldn't be configuring
                                setInConfigureMode(configure);
                                if (configure) {
                                    onConfigure({ id, configure, context: { fullscreen: false } });
                                }
                            }
                        }
                        break;
                    case NotificationType.CONFIGURE_SAVE:
                        {
                            const { id: partId } = payload;
                            if (partId === id) {
                                /* console.log('TF:NotificationType.CONFIGURE_SAVE', { partId }); */
                                handleNotificationSave();
                            }
                        }
                        break;
                    case NotificationType.CONFIGURE_CANCEL:
                        {
                            const { id: partId } = payload;
                            if (partId === id) {
                                /* console.log('TF:NotificationType.CONFIGURE_CANCEL', { partId }); */
                                setInConfigureMode(false);
                            }
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
    }, [props.notify, handleNotificationSave]);
    const [portalEl, setPortalEl] = useState(null);
    useEffect(() => {
        // timeout to give modal a moment to load
        setTimeout(() => {
            const el = document.getElementById(props.portal);
            // console.log('portal changed', { el, p: props.portal });
            if (el) {
                setPortalEl(el);
            }
        }, 10);
    }, [inConfigureMode, props.portal]);
    /* console.log('TF RENDER', { id, htmlPreview }); */
    if (htmlPreviewRef.current) {
        const latestPreview = ((_a = htmlPreviewRef.current) === null || _a === void 0 ? void 0 : _a.innerHTML) || '';
        if (latestPreview !== htmlPreview) {
            setHtmlPreview(latestPreview);
        }
    }
    const renderIt = inConfigureMode && portalEl ? (<Editor html={htmlPreview} tree={tree} portal={portalEl}/>) : (<React.Fragment>
        <style>
          {/*
      note these custom styles are for dealing with KIP / legacy content * that are applied
      we may need to do something else for the new theme and/or the themeless?
    */}
          {`
        .text-flow-authoring-preview {
          font-size: 13px;
        }
        .text-flow-authoring-preview p {
          margin: 0;
        }
      `}
        </style>
        <div ref={htmlPreviewRef} className="text-flow-authoring-preview" style={styles}>
          {tree === null || tree === void 0 ? void 0 : tree.map((subtree) => renderFlow(`textflow-${guid()}`, subtree, styleOverrides, {}, fontSize))}
        </div>
      </React.Fragment>);
    return ready ? renderIt : null;
};
export const tagName = 'janus-text-flow';
export default TextFlowAuthor;
//# sourceMappingURL=TextFlowAuthor.jsx.map