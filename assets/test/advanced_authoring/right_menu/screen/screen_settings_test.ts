import {
  transformScreenModeltoSchema,
  transformScreenSchematoModel,
} from 'apps/authoring/components/PropertyEditor/schemas/screen';
import { screen, screen1, transformedSchema } from './screen_mocks';

describe('transforming screen structure to screen schema and back to structure', () => {
  it('should transform activity structure to screen schema', () => {
    const schema = transformScreenModeltoSchema(screen);
    expect(schema.palette.backgroundColor).toEqual('rgba(0,0,0,1)');
    const changes = transformScreenSchematoModel(schema);
    expect(changes.palette.useHtmlProps).toEqual(true);
    expect(changes).toMatchObject(transformedSchema);
  });

  it('should transform activity structure to screen schema', () => {
    const schema = transformScreenModeltoSchema(screen1);
    expect(schema.palette.backgroundColor).toEqual('rgba(255,255,255,1)');
    const changes = transformScreenSchematoModel(schema);
    expect(changes).toMatchObject(transformedSchema);
  });

});
