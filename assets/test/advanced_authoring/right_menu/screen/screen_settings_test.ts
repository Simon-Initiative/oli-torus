import {
  transformScreenModeltoSchema,
  transformScreenSchematoModel,
} from 'apps/authoring/components/PropertyEditor/schemas/screen';
import { screen, screenSchema, transformedSchema } from './screen_mocks';

describe('transforming activity structure to screen schema and back to activity structure', () => {
  it('should transform activity structure to screen schema', () => {
    const model = transformScreenModeltoSchema(screen);
    expect(model).toMatchObject(screenSchema);
  });

  it('should transform lesson schema to activity structure', () => {
    const lessonStructure = transformScreenSchematoModel(screenSchema);
    expect(lessonStructure).toMatchObject(transformedSchema);
  });
});
