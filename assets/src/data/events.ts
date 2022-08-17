export interface SurveyDetails {
  id: string;
}

export interface TorusEventMap {
  'oli-survey-submit': CustomEvent<SurveyDetails>;
  'oli-survey-reset': CustomEvent<SurveyDetails>;
}

export enum Registry {
  SurveySubmit = 'oli-survey-submit',
  SurveyReset = 'oli-survey-reset',
}

export function makeSurveySubmitEvent(detail: SurveyDetails) {
  return new CustomEvent(Registry.SurveySubmit, { detail });
}

export function makeSurveyResetEvent(detail: SurveyDetails) {
  return new CustomEvent(Registry.SurveyReset, { detail });
}

declare global {
  interface Document {
    //adds definition to Document, but you can do the same with HTMLElement
    addEventListener<K extends keyof TorusEventMap>(
      type: K,
      listener: (this: Document, ev: TorusEventMap[K]) => void,
    ): void;
  }
}

export function dispatch<K extends keyof TorusEventMap>(kind: Registry, event: TorusEventMap[K]) {
  return document.dispatchEvent(event);
}
