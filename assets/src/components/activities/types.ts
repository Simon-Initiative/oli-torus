import { ResourceContext } from 'data/content/resource';

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

export interface ActivityModelSchema {
  authoring?: any;
}


export interface CreationContext extends ResourceContext {

}
