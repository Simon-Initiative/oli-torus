import type { PartComponentRegistration } from 'apps/authoring/store/app/slice';

export interface ContextProps {
  currentActivity: string;
  mode: string;
  host?: HTMLElement;
  responsiveLayout?: boolean;
  partComponentTypes?: readonly PartComponentRegistration[];
}

export interface InitResultProps {
  snapshot: Record<string, unknown>;
  context: ContextProps;
  env?: any;
  responsiveLayout?: boolean;
}
