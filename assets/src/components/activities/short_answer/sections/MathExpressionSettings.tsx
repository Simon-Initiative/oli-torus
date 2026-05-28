import React, { useMemo, useState } from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
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

type SupportedUnitsSelectProps = {
  disabled: boolean;
  selectedUnits: string[];
  onChange: (units: string[]) => void;
};

const unitBadgeStyle: React.CSSProperties = {
  backgroundColor: '#e7f1ff',
  border: '1px solid #9ec5fe',
  color: '#084298',
  fontWeight: 600,
};

const unitSelectButtonStyle: React.CSSProperties = {
  minHeight: 38,
  borderColor: '#adb5bd',
  backgroundColor: '#fff',
  boxShadow: 'inset 0 1px 1px rgba(0, 0, 0, 0.04)',
};

const unitSelectCaretContainerStyle: React.CSSProperties = {
  alignSelf: 'stretch',
  borderLeft: '1px solid #ced4da',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  marginLeft: 16,
  paddingLeft: 14,
  minWidth: 28,
};

const unitSelectCaretStyle = (open: boolean): React.CSSProperties =>
  open
    ? {
        width: 0,
        height: 0,
        borderLeft: '5px solid transparent',
        borderRight: '5px solid transparent',
        borderBottom: '5px solid #495057',
      }
    : {
        width: 0,
        height: 0,
        borderLeft: '5px solid transparent',
        borderRight: '5px solid transparent',
        borderTop: '5px solid #495057',
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
    <div>
      {selectedUnits.length > 0 && (
        <div className="d-flex flex-wrap mb-2" style={{ gap: 6 }}>
          {selectedUnits.map((unit) => (
            <button
              key={unit}
              disabled={disabled}
              type="button"
              className="badge d-inline-flex align-items-center px-2 py-1"
              style={unitBadgeStyle}
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
        className="btn d-flex align-items-center w-100 text-left"
        style={unitSelectButtonStyle}
        aria-expanded={open}
        onClick={() => setOpen(!open)}
      >
        <span className="text-truncate" style={{ flex: 1, minWidth: 0 }}>
          {selectedUnits.length === 0
            ? 'Select allowed units'
            : `${selectedUnits.length} unit${selectedUnits.length === 1 ? '' : 's'} selected`}
        </span>
        <span aria-hidden="true" style={unitSelectCaretContainerStyle}>
          <span style={unitSelectCaretStyle(open)} />
        </span>
      </button>
      <div className="position-relative">
        {open && (
          <div
            className="position-absolute bg-white border rounded shadow-sm mt-1 p-2 w-100"
            style={{ zIndex: 20, maxHeight: 320, overflowY: 'auto' }}
          >
            <input
              autoFocus
              type="text"
              className="form-control mb-2"
              placeholder="Search units"
              value={query}
              onChange={({ target: { value } }) => setQuery(value)}
            />
            {Object.entries(groupedOptions).map(([group, options]) => (
              <div key={group} className="mb-2">
                <div className="text-muted small font-weight-bold mb-1">{group}</div>
                {options.map((option) => (
                  <label key={option.value} className="d-flex align-items-center mb-1">
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
            {filteredOptions.length === 0 && <div className="text-muted small">No units found</div>}
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
    <div className="d-flex flex-column mt-3 mb-3 p-3 border rounded bg-white">
      <label className="form-label mb-2" style={{ fontWeight: 700 }}>
        Allowed variables
      </label>
      <input
        disabled={!editMode}
        type="text"
        className="form-control mb-2"
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
            className="form-control"
            placeholder="Variable"
            value={domain.name}
            onChange={({ target: { value } }) => updateDomain(index, { name: value })}
          />
          <input
            disabled={!editMode}
            type="number"
            className="form-control"
            placeholder="Min"
            value={domain.lower.value}
            onChange={({ target: { value } }) =>
              updateDomain(index, { lower: { ...domain.lower, value: Number(value) } })
            }
          />
          <select
            disabled={!editMode}
            className="form-control"
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
            className="form-control"
            placeholder="Max"
            value={domain.upper.value}
            onChange={({ target: { value } }) =>
              updateDomain(index, { upper: { ...domain.upper, value: Number(value) } })
            }
          />
          <select
            disabled={!editMode}
            className="form-control"
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
            className="form-control"
            placeholder={`${domain.name || 'Variable'} excluded values`}
            value={(domain.exclusions ?? []).join(', ')}
            onChange={({ target: { value } }) =>
              updateDomain(index, { exclusions: parseNumberList(value) })
            }
          />
          <input
            disabled={!editMode}
            type="text"
            className="form-control"
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
          <div className="d-flex flex-column mt-3 mb-3 p-3 border rounded bg-white">
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

  return variableSettings || unitSettings ? (
    <>
      {variableSettings}
      {unitSettings}
    </>
  ) : null;
};
