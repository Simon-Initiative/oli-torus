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

// export function fromActivityModelToAuthoring<T
//   extends ActivityModelSchema>(schema: T): Omit<T & T['authoring'], 'authoring'>  {
//   return Object.entries(schema).reduce((acc: any, [key, value]: [string, any]) => {
//     if (key !== 'authoring') {
//       acc[key] = value;
//       return acc;
//     }
//     return Object.assign(acc, value);
//   }, {});
// }

// export function fromAuthoringToActivityModel<T extends ActivityModelSchema>(schema: Omit<T & T['authoring'], 'authoring'>): T {
//   return Object.entries(schema).reduce((acc: any, [key, value]: [string, any]) => {

//   }, {});
// }

// export function fromActivityModelToDelivery() {

// }

// export function fromDeliveryToActivityModel() {

// }


export interface CreationContext extends ResourceContext {

}
