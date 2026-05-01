export interface ContextProps {
  currentActivity: string;
  mode: string;
  host?: HTMLElement;
  responsiveLayout?: boolean;
  partComponentTypes?: any[];
}

export interface InitResultProps {
  snapshot: Record<string, unknown>;
  context: ContextProps;
  env?: any;
  responsiveLayout?: boolean;
}
