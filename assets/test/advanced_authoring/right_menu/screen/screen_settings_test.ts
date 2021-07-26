import {
  transformScreenModeltoSchema,
  transformScreenSchematoModel,
} from 'apps/authoring/components/PropertyEditor/schemas/screen';
import { screen, transformedSchema } from './screen_mocks';

describe('transforming screen structure to screen schema and back to structure', () => {
  it('should transform activity structure to screen schema', () => {
    const schema = transformScreenModeltoSchema(screen);
    const changes = transformScreenSchematoModel(schema);
    console.log('changes', changes);
    expect(changes).toMatchObject(transformedSchema);
  });
});
