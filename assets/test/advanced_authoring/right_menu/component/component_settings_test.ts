import {
  transformModelToSchema,
  transformSchemaToModel,
} from 'apps/authoring/components/PropertyEditor/schemas/part';
import { componentData, transformedSchema } from './component_mocks';

describe('transforming component data structure to schema and back to data structure', () => {
  it('should transform component data structure to schema and back to structure after changes', () => {
    const model = transformSchemaToModel(componentData);
    const changes = transformModelToSchema(model);
    expect(changes).toMatchObject(transformedSchema);
    expect(changes.custom).toMatchObject(transformedSchema.custom);
  });
});
