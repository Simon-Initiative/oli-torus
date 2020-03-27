
export type EditorDesc = {
  deliveryElement: string;
  authoringElement: string;
  icon: string;
  description: string;
  friendlyName: string;
};

export interface ActivityEditorMap {

  // Index signature
  [prop: string]: Editor;
}
