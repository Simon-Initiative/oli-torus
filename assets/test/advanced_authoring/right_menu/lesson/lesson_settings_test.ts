import {
  transformModelToSchema as transformLessonModel,
  transformSchemaToModel as transformLessonSchema,
} from 'apps/authoring/components/PropertyEditor/schemas/lesson';
import { lesson, lessonSchema, transformedSchema } from './lesson_mocks';

describe('transforming activity structure to lesson schema and back to activity structure', () => {
  it('should transform activity structure to lesson schema', () => {
    const model = transformLessonModel(lesson);
    expect(model).toMatchObject(lessonSchema);
    expect(model.Properties).toMatchObject(lessonSchema.Properties);
    expect(model.CustomLogic).toMatchObject(lessonSchema.CustomLogic);
  });

  it('should transform lesson schema to activity structure', () => {
    const lessonStructure = transformLessonSchema(lessonSchema);
    expect(lessonStructure).toMatchObject(transformedSchema);
    expect(lessonStructure.custom).toMatchObject(transformedSchema.custom);
  });
});
