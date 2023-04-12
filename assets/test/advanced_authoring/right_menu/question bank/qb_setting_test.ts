import { bank, transformedSchema } from './bank_mocks';
import {
  transformBankModeltoSchema,
  transformBankSchematoModel,
} from 'apps/authoring/components/PropertyEditor/schemas/bank';

describe('convert sequence to bank schema and revert back to sequence data', () => {
  it('convert sequence to bank schema and revert back to sequence data', () => {
    const model = transformBankModeltoSchema(bank);
    const changes = transformBankSchematoModel(model);
    expect(changes).toMatchObject(transformedSchema);
  });
});
