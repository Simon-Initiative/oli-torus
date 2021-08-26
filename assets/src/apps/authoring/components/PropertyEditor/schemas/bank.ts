import { UiSchema } from '@rjsf/core';
import { SequenceBank, SequenceEntry } from 'apps/delivery/store/features/groups/actions/sequence';
import { JSONSchema7 } from 'json-schema';

const bankSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    bankShowCount: { type: 'number', title: 'Randomly selects question(s) from the bank' },
    bankEndTarget: { type: 'string', title: 'When Completed, proceed to' },
  },
};

export const bankUiSchema: UiSchema = {
  bankEndTarget: {
    'ui:widget': 'ScreenDropdownTemplate',
  },
};

export const transformBankModeltoSchema = (currentSequence: SequenceEntry<SequenceBank> | null) => {
  if (currentSequence) {
    const schemaData = {
      bankShowCount: currentSequence?.custom.bankShowCount || 1,
      bankEndTarget: currentSequence?.custom.bankEndTarget,
    };
    return schemaData;
  }
};

export const transformBankSchematoModel = (schema: any) => {
  const modelData = {
    bankShowCount: schema.bankShowCount,
    bankEndTarget: schema.bankEndTarget,
  };
  return modelData;
};

export default bankSchema;
