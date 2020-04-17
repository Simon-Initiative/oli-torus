import { ActivityModelSchema } from './types';

export interface AuthoringElementProps<T extends ActivityModelSchema> {
  model: T;
  onEdit: (model: T) => void;
}

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
