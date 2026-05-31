import React, { useMemo, useState } from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { ChevronDown } from 'components/misc/icons/Icons';
import {
  MathExpressionQuestionConfig,
  MathExpressionQuestionType,
  UnitPolicy,
  VariableDomain,
} from 'data/activities/model/match';
import { SupportedUnitOption, supportedUnitOptions } from './supportedUnitOptions';

type Props = {
  questionType: MathExpressionQuestionType;
  config: MathExpressionQuestionConfig;
  onChange: (config: MathExpressionQuestionConfig) => void;
};

const variableConfigTypes: MathExpressionQuestionType[] = ['algebraic', 'expression_with_units'];

const numericConfigTypes: MathExpressionQuestionType[] = ['numeric'];

const unitTypes: MathExpressionQuestionType[] = ['number_with_units', 'expression_with_units'];

const defaultDomain = (name = 'x'): VariableDomain => ({
  name,
  lower: { value: -10, inclusive: true },
  upper: { value: 10, inclusive: true },
  exclusions: [],
  integerOnly: false,
  preferredValues: [],
});

const parseList = (value: string) =>
  value
    .split(',')
    .map((part) => part.trim())
    .filter((part) => part.length > 0);

const parseNumberList = (value: string) =>
  parseList(value)
    .map((part) => Number(part))
    .filter((part) => Number.isFinite(part));

const unitPolicyUnits = (unitPolicy: UnitPolicy | undefined): string[] => {
  switch (unitPolicy?.type) {
    case 'accepted_units':
    case 'convertible_units':
      return unitPolicy.units;
    case 'strict_unit':
      return [unitPolicy.unit];
    default:
      return [];
  }
};

const panelClassName =
  'd-flex flex-column mt-3 mb-3 p-3 border rounded bg-white text-body-color dark:border-gray-700 dark:bg-body-dark dark:text-body-color-dark';

const controlClassName =
  'form-control dark:border-gray-600 dark:bg-body-dark dark:text-body-color-dark dark:placeholder-gray-400 dark:disabled:bg-gray-800 dark:disabled:text-gray-500';

type SupportedUnitsSelectProps = {
  disabled: boolean;
  selectedUnits: string[];
  onChange: (units: string[]) => void;
};

const SupportedUnitsSelect: React.FC<SupportedUnitsSelectProps> = ({
  disabled,
  selectedUnits,
  onChange,
}) => {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const selectedUnitSet = useMemo(() => new Set(selectedUnits), [selectedUnits]);
  const normalizedQuery = query.trim().toLowerCase();
  const filteredOptions = supportedUnitOptions.filter((option) =>
    option.displayValue.toLowerCase().includes(normalizedQuery),
  );
  const groupedOptions = filteredOptions.reduce<Record<string, SupportedUnitOption[]>>(
    (groups, option) => ({
      ...groups,
      [option.group]: [...(groups[option.group] ?? []), option],
    }),
    {},
  );

  const toggleUnit = (unit: string) => {
    onChange(
      selectedUnitSet.has(unit)
        ? selectedUnits.filter((selected) => selected !== unit)
        : [...selectedUnits, unit],
    );
  };

  return (
    <div className="text-body-color dark:text-body-color-dark">
      {selectedUnits.length > 0 && (
        <div className="mb-2 flex flex-wrap" style={{ gap: 6 }}>
          {selectedUnits.map((unit) => (
            <button
              key={unit}
              disabled={disabled}
              type="button"
              className="inline-flex items-center rounded border border-blue-300 bg-blue-50 px-2 py-1 text-xs font-semibold text-blue-900 disabled:cursor-not-allowed disabled:opacity-75 dark:border-blue-500 dark:bg-blue-900 dark:text-blue-100"
              onClick={() => toggleUnit(unit)}
              aria-label={`Remove ${unit}`}
            >
              <span>{unit}</span>
              <span className="ml-1" aria-hidden="true">
                x
              </span>
            </button>
          ))}
        </div>
      )}
      <button
        disabled={disabled}
        type="button"
        className="flex min-h-[38px] w-full items-center rounded border border-gray-400 bg-white px-3 py-1.5 text-left text-body-color shadow-inner disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500 disabled:opacity-75 dark:border-gray-600 dark:bg-body-dark dark:text-body-color-dark dark:disabled:bg-gray-800 dark:disabled:text-gray-500"
        aria-expanded={open}
        onClick={() => setOpen(!open)}
      >
        <span className="text-truncate" style={{ flex: 1, minWidth: 0 }}>
          {selectedUnits.length === 0
            ? 'Select allowed units'
            : `${selectedUnits.length} unit${selectedUnits.length === 1 ? '' : 's'} selected`}
        </span>
        <span
          aria-hidden="true"
          className="ml-4 flex min-w-[28px] self-stretch border-l border-gray-300 pl-3 dark:border-gray-600"
        >
          <ChevronDown
            className={`h-4 w-4 self-center text-gray-600 transition-transform dark:text-gray-300 ${
              open ? 'rotate-180' : ''
            }`}
          />
        </span>
      </button>
      <div className="position-relative">
        {open && (
          <div
            className="position-absolute mt-1 w-100 rounded border border-gray-300 bg-white p-2 shadow-sm dark:border-gray-600 dark:bg-body-dark dark:text-body-color-dark"
            style={{ zIndex: 20, maxHeight: 320, overflowY: 'auto' }}
          >
            <input
              autoFocus
              type="text"
              className={`${controlClassName} mb-2`}
              placeholder="Search units"
              value={query}
              onChange={({ target: { value } }) => setQuery(value)}
            />
            {Object.entries(groupedOptions).map(([group, options]) => (
              <div key={group} className="mb-2">
                <div className="text-muted small font-weight-bold mb-1 dark:!text-gray-300">
                  {group}
                </div>
                {options.map((option) => (
                  <label
                    key={option.value}
                    className="d-flex align-items-center mb-1 text-body-color dark:text-body-color-dark"
                  >
                    <input
                      type="checkbox"
                      className="mr-2"
                      checked={selectedUnitSet.has(option.value)}
                      onChange={() => toggleUnit(option.value)}
                    />
                    <span>{option.displayValue}</span>
                  </label>
                ))}
              </div>
            ))}
            {filteredOptions.length === 0 && (
              <div className="text-muted small dark:!text-gray-300">No units found</div>
            )}
            {selectedUnits.length > 0 && (
              <button type="button" className="btn btn-link p-0" onClick={() => onChange([])}>
                Clear selected units
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export const MathExpressionSettings: React.FC<Props> = ({ questionType, config, onChange }) => {
  const { editMode } = useAuthoringElementContext();
  const validation = config.validation ?? { allowedVariables: [], domains: [] };
  const unitPolicy = config.unitPolicy ?? { type: 'convertible_units', units: ['m/s'] };

  const updateValidation = (nextValidation: MathExpressionQuestionConfig['validation']) =>
    onChange({ ...config, validation: nextValidation });

  const updateDomain = (index: number, update: Partial<VariableDomain>) => {
    const domains = [...(validation.domains ?? [])];
    domains[index] = { ...domains[index], ...update };
    updateValidation({ ...validation, domains });
  };

  const variableSettings = variableConfigTypes.includes(questionType) ? (
    <div className={panelClassName}>
      <label className="form-label mb-2" style={{ fontWeight: 700 }}>
        Allowed variables
      </label>
      <input
        disabled={!editMode}
        type="text"
        className={`${controlClassName} mb-2`}
        placeholder="x, y"
        value={(validation.allowedVariables ?? []).join(', ')}
        onChange={({ target: { value } }) =>
          updateValidation({ ...validation, allowedVariables: parseList(value) })
        }
      />
      {(validation.domains ?? []).map((domain, index) => (
        <div key={index} className="d-flex flex-column flex-lg-row mb-2 gap-2">
          <input
            disabled={!editMode}
            type="text"
            className={controlClassName}
            placeholder="Variable"
            value={domain.name}
            onChange={({ target: { value } }) => updateDomain(index, { name: value })}
          />
          <input
            disabled={!editMode}
            type="number"
            className={controlClassName}
            placeholder="Min"
            value={domain.lower.value}
            onChange={({ target: { value } }) =>
              updateDomain(index, { lower: { ...domain.lower, value: Number(value) } })
            }
          />
          <select
            disabled={!editMode}
            className={controlClassName}
            value={domain.lower.inclusive ? 'inclusive' : 'exclusive'}
            onChange={({ target: { value } }) =>
              updateDomain(index, {
                lower: { ...domain.lower, inclusive: value === 'inclusive' },
              })
            }
          >
            <option value="inclusive">Min inclusive</option>
            <option value="exclusive">Min exclusive</option>
          </select>
          <input
            disabled={!editMode}
            type="number"
            className={controlClassName}
            placeholder="Max"
            value={domain.upper.value}
            onChange={({ target: { value } }) =>
              updateDomain(index, { upper: { ...domain.upper, value: Number(value) } })
            }
          />
          <select
            disabled={!editMode}
            className={controlClassName}
            value={domain.upper.inclusive ? 'inclusive' : 'exclusive'}
            onChange={({ target: { value } }) =>
              updateDomain(index, {
                upper: { ...domain.upper, inclusive: value === 'inclusive' },
              })
            }
          >
            <option value="inclusive">Max inclusive</option>
            <option value="exclusive">Max exclusive</option>
          </select>
          <label className="d-flex align-items-center mb-0">
            <input
              disabled={!editMode}
              type="checkbox"
              className="mr-1"
              checked={domain.integerOnly === true}
              onChange={({ target: { checked } }) => updateDomain(index, { integerOnly: checked })}
            />
            Integer
          </label>
          <button
            disabled={!editMode}
            type="button"
            className="btn btn-link text-danger"
            onClick={() =>
              updateValidation({
                ...validation,
                domains: (validation.domains ?? []).filter((_, i) => i !== index),
              })
            }
          >
            Remove
          </button>
        </div>
      ))}
      {(validation.domains ?? []).map((domain, index) => (
        <div key={`lists-${index}`} className="d-flex flex-column flex-md-row mb-2 gap-2">
          <input
            disabled={!editMode}
            type="text"
            className={controlClassName}
            placeholder={`${domain.name || 'Variable'} excluded values`}
            value={(domain.exclusions ?? []).join(', ')}
            onChange={({ target: { value } }) =>
              updateDomain(index, { exclusions: parseNumberList(value) })
            }
          />
          <input
            disabled={!editMode}
            type="text"
            className={controlClassName}
            placeholder={`${domain.name || 'Variable'} preferred values`}
            value={(domain.preferredValues ?? []).join(', ')}
            onChange={({ target: { value } }) =>
              updateDomain(index, { preferredValues: parseNumberList(value) })
            }
          />
        </div>
      ))}
      <button
        disabled={!editMode}
        type="button"
        className="btn btn-link align-self-start p-0"
        onClick={() =>
          updateValidation({
            ...validation,
            domains: [
              ...(validation.domains ?? []),
              defaultDomain(validation.allowedVariables?.[0] ?? 'x'),
            ],
          })
        }
      >
        Add variable domain
      </button>
    </div>
  ) : null;

  const numericSettings = numericConfigTypes.includes(questionType) ? (
    <div className={panelClassName}>
      <label className="form-label mb-2" style={{ fontWeight: 700 }}>
        Numeric settings
      </label>
      <label className="d-flex align-items-center mb-0 text-body-color dark:text-body-color-dark">
        <input
          disabled={!editMode}
          type="checkbox"
          className="mr-1"
          checked={config.numeric?.integerOnly === true}
          onChange={({ target: { checked } }) =>
            onChange({
              ...config,
              numeric: {
                ...(config.numeric ?? {}),
                integerOnly: checked,
              },
            })
          }
        />
        Integer only
      </label>
    </div>
  ) : null;

  const unitSettings = unitTypes.includes(questionType)
    ? (() => {
        const units = unitPolicyUnits(unitPolicy);
        const allowConversion = unitPolicy.type !== 'accepted_units';
        const updateUnitPolicy = (nextUnits: string[], nextAllowConversion = allowConversion) =>
          onChange({
            ...config,
            unitPolicy: {
              type: nextAllowConversion ? 'convertible_units' : 'accepted_units',
              units: nextUnits,
            },
          });

        return (
          <div className={panelClassName}>
            <label className="form-label mb-2" style={{ fontWeight: 700 }}>
              Allowed units
            </label>
            <SupportedUnitsSelect
              disabled={!editMode}
              selectedUnits={units}
              onChange={(nextUnits) => updateUnitPolicy(nextUnits)}
            />
            <label className="d-flex align-items-center mt-2 mb-0">
              <input
                disabled={!editMode}
                type="checkbox"
                className="mr-1"
                checked={allowConversion}
                onChange={({ target: { checked } }) => updateUnitPolicy(units, checked)}
              />
              Allow unit conversion
            </label>
          </div>
        );
      })()
    : null;

  return variableSettings || numericSettings || unitSettings ? (
    <>
      {variableSettings}
      {numericSettings}
      {unitSettings}
    </>
  ) : null;
};
