import {
  transformModelToSchema as transformLessonModel,
  transformSchemaToModel as transformLessonSchema,
} from 'apps/authoring/components/PropertyEditor/schemas/lesson';
import { lesson, transformedSchema } from './lesson_mocks';

describe('transforming lesson structure to lesson schema and back to lesson structure', () => {
  it('should transform lesson structure to schema and back to structure after changes', () => {
    const model = transformLessonModel(lesson);
    const changes = transformLessonSchema(model);
    expect(changes).toMatchObject(transformedSchema);
    expect(changes.custom).toMatchObject(transformedSchema.custom);
  });
});
