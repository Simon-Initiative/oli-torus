import { ActivityModelSchema } from './types';
import { ActivitySlug } from 'data/types';

export interface DeliveryElementProps<T extends ActivityModelSchema> {
  activitySlug: ActivitySlug;
  model: T;
}

// An abstract delivery web component, designed to delegate to
// a React component.  This delivery web component will re-render
// the underlying React component when the 'model' attribute of the
// the web component changes
export abstract class DeliveryElement<T extends ActivityModelSchema> extends HTMLElement {

  mountPoint: HTMLDivElement;

  constructor() {
    super();
    this.mountPoint = document.createElement('div');
  }

  props() : DeliveryElementProps<T> {

    const model = JSON.parse(this.getAttribute('model') as any);
    const activitySlug = this.getAttribute('activitySlug') as any;

    return {
      model,
      activitySlug,
    };
  }

  abstract render(mountPoint: HTMLDivElement, props: DeliveryElementProps<T>) : void;

  connectedCallback() {
    this.appendChild(this.mountPoint);
    this.render(this.mountPoint, this.props());
  }

  attributeChangedCallback(name: any, oldValue: any, newValue: any) {
    this.render(this.mountPoint, this.props());
  }

  static get observedAttributes() { return ['model']; }
}
