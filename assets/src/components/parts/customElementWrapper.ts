/*
modified from the following source to work with React and suit adaptive needs:
preact-custom-element
The MIT License (MIT)
Copyright (c) 2016 Bradley Spaulding
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

// tslint:disable: max-classes-per-file

import React from 'react';
import ReactDOM from 'react-dom';

function toCamelCase(str: string) {
  return str.replace(/-(\w)/g, (_, c) => (c ? c.toUpperCase() : ''));
}

class ContextProvider extends React.Component<{ context: any; children: any }> {
  static childContextTypes = {
    context: () => null,
  };

  getChildContext() {
    return this.props.context;
  }

  render() {
    const { context, children, ...rest } = this.props;
    return React.cloneElement(children, rest);
  }
}

/**
 * Pass an event listener to each `<slot>` that "forwards" the current
 * context value to the rendered child. The child will trigger a custom
 * event, where will add the context value to. Because events work
 * synchronously, the child can immediately pull of the value right
 * after having fired the event.
 */
class Slot extends React.Component {
  ref: any;
  _listener: any;

  constructor(props: any) {
    super(props);
    // this.ref = React.createRef();
  }

  render() {
    const ref = (r: any) => {
      if (!r) {
        this.ref.removeEventListener('__react', this._listener);
      } else {
        this.ref = r;
        if (!this._listener) {
          this._listener = (event: any) => {
            event.stopPropagation();
            // event.detail.context = context;
          };
          r.addEventListener('__react', this._listener);
        }
      }
    };
    return React.createElement('slot', { ...this.props, ref });
  }
}

function toVdom(element: any, nodeName: any) {
  if (element.nodeType === 3) return element.data;
  if (element.nodeType !== 1) return null;
  const children: any[] = [];
  const props: any = {};
  let i = 0;
  const a = element.attributes;
  const cn = element.childNodes;
  for (i = a.length; i--; ) {
    if (a[i].name !== 'slot') {
      props[a[i].name] = a[i].value;
      props[toCamelCase(a[i].name)] = a[i].value;
    }
  }

  for (i = cn.length; i--; ) {
    const vnode = toVdom(cn[i], null);
    // Move slots correctly
    const name = cn[i].slot;
    if (name) {
      props[name] = React.createElement(Slot, { name }, vnode);
    } else {
      children[i] = vnode;
    }
  }

  // Only wrap the topmost node with a slot
  const wrappedChildren = nodeName ? React.createElement(Slot, null, children) : children;

  return React.createElement(nodeName || element.nodeName.toLowerCase(), props, wrappedChildren);
}

abstract class ReactCustomElement extends HTMLElement {
  // TODO: typings
  protected _vdomComponent: any;
  protected _vdom: any;
  protected _root: any;
  protected _props: any;
  protected _customEvents: any;

  constructor() {
    super();

    this._vdom = null;
    this._vdomComponent = null;
    this._root = this;
    this._props = {};
    this._customEvents = {};
  }

  connectedCallback() {
    interface CustomEventDetails {
      context?: any;
    }
    const event = new CustomEvent<CustomEventDetails>('__react', {
      detail: { context: null },
      bubbles: true,
      cancelable: true,
    });
    this.dispatchEvent(event);
    const context = event.detail.context;

    this._vdom = React.createElement(
      ContextProvider,
      { ...this._props, ...this._customEvents, context },
      toVdom(this, this._vdomComponent),
    );
    ReactDOM.render(this._vdom, this._root);
  }

  disconnectedCallback() {
    this._vdom = null;
    // the following was in preact, not sure if is needed
    // ReactDOM.render(null, this._root);
  }

  attributeChangedCallback(name: string, oldValue: any, newValue: any) {
    if (!this._vdom) return;
    // Attributes use `null` as an empty value whereas `undefined` is more
    // common in pure JS components, especially with default parameters.
    // When calling `node.removeAttribute()` we'll receive `null` as the new
    // value. See issue #50.
    newValue = newValue == null ? undefined : newValue;
    const props: any = {};
    props[name] = newValue;
    props[toCamelCase(name)] = newValue;
    this._vdom = React.cloneElement(this._vdom, props);
    ReactDOM.render(this._vdom, this._root);
  }

  dispatch(eventName: string, payload: any) {
    return new Promise((resolve, reject) => {
      const callback = (result: any, error: any) => {
        if (error !== undefined) {
          reject(error);
          return;
        }
        resolve(result);
      };
      this.dispatchEvent(
        new CustomEvent(eventName, {
          bubbles: true,
          detail: { callback, payload },
        }),
      );
    });
  }
}

const register = (Component: any, tagName?: string, watchedPropNames?: string[], options?: any) => {
  // tslint:disable-next-line: max-classes-per-file
  class CustomElement extends ReactCustomElement {
    static observedAttributes =
      watchedPropNames || Component.observedAttributes || Object.keys(Component.propTypes || {});

    constructor() {
      super();

      this._vdomComponent = Component;
      this._root = options && options.shadow ? this.attachShadow({ mode: 'open' }) : this;

      // Keep DOM properties and React props in sync
      CustomElement.observedAttributes.forEach((name: string) => {
        Object.defineProperty(this, name, {
          get() {
            return this._vdom.props[name];
          },
          set(v) {
            if (this._vdom) {
              this.attributeChangedCallback(name, null, v);
            } else {
              if (!this._props) this._props = {};
              this._props[name] = v;
              // this.connectedCallback();
            }

            // Reflect property changes to attributes if the value is a primitive
            const type = typeof v;
            if (v == null || type === 'string' || type === 'boolean' || type === 'number') {
              this.setAttribute(name, v);
            }
          },
        });
      });

      const customEvents = (options && options.customEvents) || Component.customEvents;
      if (customEvents) {
        Object.keys(customEvents).forEach((eventName) => {
          const emitName = customEvents[eventName] || eventName;
          const handler = (payload: any) => this.dispatch(emitName, payload);
          // later to propagate to props
          this._customEvents[eventName] = handler;
          Object.defineProperty(this, eventName, {
            get() {
              return handler;
            },
          });
        });
      }
    }
  }

  return customElements.define(
    tagName || Component.tagName || Component.displayName || Component.name,
    CustomElement,
  );
};

export default register;
