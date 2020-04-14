
export type ModeSpecification = {
  element: string,
  entry: string,
};

export type Manifest = {
  id: string,
  friendlyName: string,
  description: string,
  delivery: ModeSpecification,
  authoring: ModeSpecification,
};
