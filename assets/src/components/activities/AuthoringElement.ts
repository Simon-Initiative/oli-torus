import { ActivityModelSchema } from './types';

export interface AuthoringElementProps<T extends ActivityModelSchema> {
  model: T;
  onEdit: (model: T) => void;
}

// An abstract authoring web component, designed to delegate to
// a React authoring component.  This authoring web component will re-render
// the underlying React component when the 'model' attribute of the
// the web component changes.  It also traps onEdit callbacks from the
// React component and translated these calls into dispatches of the
// 'modelUpdated' CustomEvent.  It is this CustomEvent that is handled by
// Torus to process updates from the authoring web component.
export abstract class AuthoringElement<T extends ActivityModelSchema> extends HTMLElement {

  mountPoint: HTMLDivElement;

  constructor() {
    super();

    this.mountPoint = document.createElement('div');
  }

  props() : AuthoringElementProps<T> {

    const model = JSON.parse(this.getAttribute('model') as any);

    const onEdit = (model: any) => {
      this.dispatchEvent(new CustomEvent('modelUpdated', { bubbles: true, detail: { model } }));
    };

    return {
      onEdit,
      model,
    };
  }

  abstract render(mountPoint: HTMLDivElement, props: AuthoringElementProps<T>) : void;

  connectedCallback() {
    this.appendChild(this.mountPoint);
    this.render(this.mountPoint, this.props());
  }

  attributeChangedCallback(name: any, oldValue: any, newValue: any) {
    this.render(this.mountPoint, this.props());
  }

  static get observedAttributes() { return ['model']; }
}
