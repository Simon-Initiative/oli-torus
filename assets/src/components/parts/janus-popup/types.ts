export interface ContextProps {
  currentActivity: string;
  mode: string;
}

export interface InitResultProps {
  snapshot: Record<string, unknown>;
  context: ContextProps;
}
