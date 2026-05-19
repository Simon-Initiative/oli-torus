import lessonSchema, {
  simpleLessonSchema,
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

  it('allows lesson titles to be edited in both adaptive authoring modes', () => {
    expect(
      ((lessonSchema.properties as any)?.Properties?.properties as any)?.title,
    ).not.toHaveProperty('readOnly');
    expect(
      ((simpleLessonSchema.properties as any)?.Properties?.properties as any)?.title,
    ).not.toHaveProperty('readOnly');

    const model = transformLessonModel(lesson);
    model.Properties.title = 'Renamed Adaptive Lesson';

    const changes = transformLessonSchema(model);

    expect(changes.title).toBe('Renamed Adaptive Lesson');
  });
});
