export interface SurveyDetails {
  id: string;
}

export interface ShowContentPage {
  forId: string;
  index: number;
}

export interface ReviewModeAttemptChange {
  forId: number;
  state: Record<string, unknown>;
  model: Record<string, unknown>;
}

export interface TorusEventMap {
  'oli-survey-submit': CustomEvent<SurveyDetails>;
  'oli-survey-reset': CustomEvent<SurveyDetails>;
  'oli-show-content-page': CustomEvent<ShowContentPage>;
  'oli-review-mode-attempt-change': CustomEvent<ReviewModeAttemptChange>;
}

export enum Registry {
  SurveySubmit = 'oli-survey-submit',
  SurveyReset = 'oli-survey-reset',
  ShowContentPage = 'oli-show-content-page',
  ReviewModeAttemptChange = 'oli-review-mode-attempt-change',
}

export function makeSurveySubmitEvent(detail: SurveyDetails) {
  return new CustomEvent(Registry.SurveySubmit, { detail });
}

export function makeSurveyResetEvent(detail: SurveyDetails) {
  return new CustomEvent(Registry.SurveyReset, { detail });
}

export function makeShowContentPage(detail: ShowContentPage) {
  return new CustomEvent(Registry.ShowContentPage, { detail });
}

export function makeReviewModeAttemptChange(detail: ReviewModeAttemptChange) {
  return new CustomEvent(Registry.ReviewModeAttemptChange, { detail });
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
