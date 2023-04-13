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
import EventEmitter from 'events';

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
    const { children, ...rest } = this.props;
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

function toVdom(element: any, nodeName: any, attrConfig: Record<string, AttrConfig> = {}) {
  if (element.nodeType === 3) return element.data;
  if (element.nodeType !== 1) return null;
  const children: any[] = [];
  const props: any = {};
  let i = 0;
  const a = element.attributes;
  const cn = element.childNodes;
  for (i = a.length; i--; ) {
    if (a[i].name !== 'slot') {
      const attrName = a[i].name;
      let attrValue = a[i].value;
      if (attrConfig[attrName] && attrConfig[attrName].json) {
        try {
          attrValue = JSON.parse(attrValue);
        } catch (e) {
          console.warn('Could not parse attribute', attrName, attrValue);
        }
      }
      props[attrName] = attrValue;
      props[toCamelCase(attrName)] = attrValue;
    }
  }

  for (i = cn.length; i--; ) {
    const vnode = toVdom(cn[i], null, attrConfig);
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
  protected _notify: any;
  protected _attrConfig: Record<string, AttrConfig>;

  constructor() {
    super();

    this._vdom = null;
    this._vdomComponent = null;
    this._root = this;
    this._props = {};
    this._customEvents = {};
    this._notify = new EventEmitter().setMaxListeners(50);
    this._attrConfig = {};
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

    const notify = this._notify;

    // React doesn't do the className magic with custom elements
    if (this.getAttribute('classname')) {
      this.setAttribute('class', this.getAttribute('classname') as string);
    }
    // special case for other classes since I can't do my own className
    if (this.getAttribute('customcssclass')) {
      const customCssClass = this.getAttribute('customcssclass') as string;
      const currentClasses = this.getAttribute('class') as string;
      if (customCssClass) {
        if (!currentClasses) {
          this.setAttribute('class', customCssClass);
        } else {
          const allClasses = customCssClass.split(' ').concat(currentClasses.split(' '));
          // TODO: unique?
          this.setAttribute('class', allClasses.join(' '));
        }
      }
    }

    this._vdom = React.createElement(
      ContextProvider,
      { ...this._props, ...this._customEvents, context, notify },
      toVdom(this, this._vdomComponent, this._attrConfig),
    );
    ReactDOM.render(this._vdom, this._root);
  }

  disconnectedCallback() {
    ReactDOM.unmountComponentAtNode(this._root);
    this._vdom = null;
  }

  attributeChangedCallback(name: string, oldValue: any, newValue: any) {
    if (name === 'classname' || name === 'customcssclass') {
      let className = newValue;
      if (this.getAttribute('customcssclass')) {
        const customCssClass = this.getAttribute('customcssclass') as string;
        const allClasses = customCssClass.split(' ').concat(newValue.split(' '));
        className = allClasses.join(' ');
      }
      this.setAttribute('class', className);
      return;
    }
    if (!this._vdom) return;
    // Attributes use `null` as an empty value whereas `undefined` is more
    // common in pure JS components, especially with default parameters.
    // When calling `node.removeAttribute()` we'll receive `null` as the new
    // value. See issue #50.
    newValue = newValue == null ? undefined : newValue;
    const props: any = {};
    if (this._attrConfig[name]) {
      if (this._attrConfig[name].json) {
        try {
          newValue = JSON.parse(newValue);
        } catch (e) {
          console.warn(`expected ${name} to contain JSON, failed to parse`, newValue);
        }
      }
    }
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
          composed: true,
          detail: { callback, payload },
        }),
      );
    });
  }

  notify(eventName: string, payload: any) {
    /* console.log('notify', { eventName, payload }); */
    // now to get into react...
    this._notify.emit(eventName, payload);
  }
}

interface AttrConfig {
  watched?: boolean;
  json?: boolean;
}
interface RegistrationOptions {
  shadow?: boolean;
  customEvents?: Record<string, string>;
  customApi?: Record<string, any>;
  attrs?: Record<string, AttrConfig>;
}

const register = (
  Component: any,
  tagName?: string,
  watchedPropNames?: string[],
  options?: RegistrationOptions,
) => {
  // tslint:disable-next-line: max-classes-per-file
  class CustomElement extends ReactCustomElement {
    static observedAttributes: string[] = [
      'classname',
      'customcssclass',
      ...(watchedPropNames ||
        Component.observedAttributes ||
        Object.keys(Component.propTypes || {})),
    ];

    constructor() {
      super();

      this._vdomComponent = Component;
      this._root = options && options.shadow ? this.attachShadow({ mode: 'open' }) : this;

      if (options && options.attrs) {
        this._attrConfig = options.attrs;
        // TODO: add / include to observedAttributes based on watched property
      }

      // Keep DOM properties and React props in sync
      CustomElement.observedAttributes.forEach((name: string) => {
        // React doesn't do its normal className prop for custom elements
        if (name === 'classname') {
          return;
        }
        Object.defineProperty(this, name, {
          get() {
            if (!this._vdom) {
              console.warn(`${name} accessed before component mounted`);
            }
            return this._vdom?.props[name] || this.getAttribute(name);
          },
          set(v) {
            if (this._vdom) {
              this.attributeChangedCallback(name, null, v);
            } else {
              if (!this._props) this._props = {};
              if (this._attrConfig[name] && this._attrConfig[name].json) {
                try {
                  this._props[name] = JSON.parse(v);
                } catch (e) {
                  console.warn(`expected ${name} to contain JSON, failed to parse`, v);
                  this._props[name] = v;
                }
              } else {
                this._props[name] = v;
              }
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

      const customApi = (options && options.customApi) || Component.customApi;
      if (customApi) {
        Object.keys(customApi).forEach((apiName) => {
          Object.defineProperty(this, apiName, { value: customApi[apiName] });
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
