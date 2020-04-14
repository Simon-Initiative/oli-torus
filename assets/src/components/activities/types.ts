
export type ModeSpecification = {
  element: string,
  entry: string,
};

export type Manifest = {
  type: string,
  friendlyName: string,
  description: string,
  delivery: ModeSpecification,
  authoring: ModeSpecification,
};
