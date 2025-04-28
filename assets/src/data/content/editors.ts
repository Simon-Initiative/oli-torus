export type EditorDesc = {
  slug: string;
  deliveryElement: string;
  authoringElement: string;
  icon: string;
  description: string;
  friendlyName: string;
  petiteLabel: string;
  globallyAvailable: boolean;
  enabledForProject: boolean;
  id: number;
  variables: any;
};

export interface ActivityEditorMap {
  // Index signature
  [prop: string]: EditorDesc;
}
