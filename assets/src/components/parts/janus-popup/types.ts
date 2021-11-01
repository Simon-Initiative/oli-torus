export interface ContextProps {
  currentActivity: string;
  mode: string;
  host?: HTMLElement;
}

export interface InitResultProps {
  snapshot: Record<string, unknown>;
  context: ContextProps;
  env?: any;
}
