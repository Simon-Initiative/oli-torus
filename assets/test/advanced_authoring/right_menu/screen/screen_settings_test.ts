import {
  transformScreenModeltoSchema,
  transformScreenSchematoModel,
} from 'apps/authoring/components/PropertyEditor/schemas/screen';
import { screen, screen1, transformedSchema } from './screen_mocks';

describe('transforming screen structure to screen schema and back to structure', () => {
  it('should transform activity structure to screen schema', () => {
    const schema = transformScreenModeltoSchema(screen);
    console.log(schema);
    const changes = transformScreenSchematoModel(schema);
    console.log('changes', changes);
    expect(changes).toMatchObject(transformedSchema);
  });

  it('should transform activity structure to screen schema', () => {
    const schema = transformScreenModeltoSchema(screen1);
    console.log(schema);
    const changes = transformScreenSchematoModel(schema);
    console.log('changes', changes);
    expect(changes).toMatchObject(transformedSchema);
  });

});
