import { UiSchema } from '@rjsf/core';
import { JSONSchema7 } from 'json-schema';
import { SequenceBank, SequenceEntry } from 'apps/delivery/store/features/groups/actions/sequence';
import AccordionTemplate from '../custom/AccordionTemplate';

const bankSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    Bank: {
      type: 'object',
      properties: {
        bankShowCount: { type: 'number', title: 'Randomly selects question(s) from the bank' },
        bankEndTarget: { type: 'string', title: 'When Completed, proceed to' },
      },
    },
  },
};

export const bankUiSchema: UiSchema = {
  Bank: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
    bankEndTarget: {
      'ui:widget': 'ScreenDropdownTemplate',
    },
  },
};

export const transformBankModeltoSchema = (currentSequence: SequenceEntry<SequenceBank> | null) => {
  if (currentSequence) {
    const schemaData = {
      Bank: {
        bankShowCount: currentSequence?.custom.bankShowCount || 1,
        bankEndTarget: currentSequence?.custom.bankEndTarget,
      },
    };
    if (!schemaData.Bank.bankEndTarget) {
      schemaData.Bank.bankEndTarget = 'next';
    } else if (schemaData.Bank.bankEndTarget.toLowerCase() === 'next') {
      schemaData.Bank.bankEndTarget = schemaData.Bank.bankEndTarget.toLowerCase();
    }
    return schemaData;
  }
};

export const transformBankSchematoModel = (schema: any) => {
  const modelData = {
    bankShowCount: schema.Bank.bankShowCount,
    bankEndTarget: schema.Bank.bankEndTarget,
  };
  return modelData;
};

export default bankSchema;
