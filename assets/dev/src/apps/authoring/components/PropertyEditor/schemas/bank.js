import AccordionTemplate from '../custom/AccordionTemplate';
const bankSchema = {
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
export const bankUiSchema = {
    Bank: {
        'ui:ObjectFieldTemplate': AccordionTemplate,
        bankEndTarget: {
            'ui:widget': 'ScreenDropdownTemplate',
        },
    },
};
export const transformBankModeltoSchema = (currentSequence) => {
    if (currentSequence) {
        const schemaData = {
            Bank: {
                bankShowCount: (currentSequence === null || currentSequence === void 0 ? void 0 : currentSequence.custom.bankShowCount) || 1,
                bankEndTarget: currentSequence === null || currentSequence === void 0 ? void 0 : currentSequence.custom.bankEndTarget,
            },
        };
        if (!schemaData.Bank.bankEndTarget) {
            schemaData.Bank.bankEndTarget = 'next';
        }
        else if (schemaData.Bank.bankEndTarget.toLowerCase() === 'next') {
            schemaData.Bank.bankEndTarget = schemaData.Bank.bankEndTarget.toLowerCase();
        }
        return schemaData;
    }
};
export const transformBankSchematoModel = (schema) => {
    const modelData = {
        bankShowCount: schema.Bank.bankShowCount,
        bankEndTarget: schema.Bank.bankEndTarget,
    };
    return modelData;
};
export default bankSchema;
//# sourceMappingURL=bank.js.map