import { getNextScreen } from 'apps/authoring/components/PropertyEditor/custom/ScreenDropdownTemplate';
import {
  transformBankModeltoSchema,
  transformBankSchematoModel,
} from 'apps/authoring/components/PropertyEditor/schemas/bank';
import { bank, transformedSchema } from './bank_mocks';

describe('convert sequence to bank schema and revert back to sequence data', () => {
  it('convert sequence to bank schema and revert back to sequence data', () => {
    const model = transformBankModeltoSchema(bank);
    console.log(model);
    const changes = transformBankSchematoModel(model);
    expect(changes).toMatchObject(transformedSchema);
  });
  it('check next sequence in case of question bank', () => {
    const model = getNextScreen();
    console.log(model);
    const changes = transformBankSchematoModel(model);
    expect(changes).toMatchObject(transformedSchema);
  });
});
