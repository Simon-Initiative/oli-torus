import React, { useEffect, useMemo, useState } from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { ChevronDown } from 'components/misc/icons/Icons';
import {
  MathExpressionQuestionConfig,
  MathExpressionQuestionType,
  SamplingConfig,
  UnitPolicy,
  VariableDomain,
} from 'data/activities/model/match';
import { defaultSamplingConfig } from '../utils';
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

const defaultVariables = ['x'];

const isValidVariableName = (name: string) => /^[A-Za-z]$/.test(name);

const uniqueVariables = (variables: string[]) =>
  variables.reduce<string[]>((kept, variable) => {
    const trimmed = variable.trim();
    if (trimmed.length === 0 || kept.includes(trimmed)) return kept;
    return [...kept, trimmed];
  }, []);

const variableList = (validation: MathExpressionQuestionConfig['validation']) => {
  const variables = uniqueVariables(validation?.allowedVariables ?? []);
  return variables.length > 0 ? variables : defaultVariables;
};

const domainForVariable = (domains: VariableDomain[] = [], variable: string) =>
  domains.find((domain) => domain.name === variable) ?? defaultDomain(variable);

const syncDomains = (domains: VariableDomain[] = [], variables: string[]) =>
  variables.map((variable) => domainForVariable(domains, variable));

const parseFiniteNumber = (value: string): number | undefined => {
  if (value.trim().length === 0) return undefined;

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
};

const parseFiniteInteger = (value: string): number | undefined => {
  if (value.trim().length === 0) return undefined;

  const parsed = Number(value);
  return Number.isInteger(parsed) ? parsed : undefined;
};

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

const helpTextClassName = 'text-sm text-gray-600 dark:text-gray-300';

const smallLabelClassName =
  'mb-1 block text-xs font-semibold uppercase text-gray-600 dark:text-gray-300';

type NumberListEditorProps = {
  disabled: boolean;
  label: string;
  description: string;
  values: number[];
  addLabel: string;
  inputLabel: string;
  onChange: (values: number[]) => void;
};

const NumberListEditor: React.FC<NumberListEditorProps> = ({
  disabled,
  label,
  description,
  values,
  addLabel,
  inputLabel,
  onChange,
}) => {
  const [draft, setDraft] = useState('');
  const parsedDraft = Number(draft);
  const canAdd = draft.trim().length > 0 && Number.isFinite(parsedDraft);

  const addValue = () => {
    if (!canAdd) return;
    onChange([...values, parsedDraft]);
    setDraft('');
  };

  return (
    <div className="rounded border border-gray-200 bg-gray-50 p-3 dark:border-gray-700 dark:bg-gray-800">
      <div className={smallLabelClassName}>{label}</div>
      <p className={`${helpTextClassName} mb-2`}>{description}</p>
      <div className="mb-2 flex min-h-[28px] flex-wrap gap-2">
        {values.length === 0 ? (
          <span className="text-sm italic text-gray-500 dark:text-gray-400">None</span>
        ) : (
          values.map((value, index) => (
            <button
              key={`${value}-${index}`}
              disabled={disabled}
              type="button"
              className="inline-flex items-center rounded border border-gray-300 bg-white px-2 py-1 text-sm text-gray-900 disabled:cursor-not-allowed disabled:opacity-75 dark:border-gray-600 dark:bg-body-dark dark:text-body-color-dark"
              onClick={() => onChange(values.filter((_, valueIndex) => valueIndex !== index))}
              aria-label={`Remove ${label.toLowerCase()} ${value}`}
            >
              <span>{value}</span>
              <span className="ml-1" aria-hidden="true">
                x
              </span>
            </button>
          ))
        )}
      </div>
      <div className="d-flex flex-column flex-sm-row gap-2">
        <input
          disabled={disabled}
          type="number"
          step="any"
          className={controlClassName}
          aria-label={inputLabel}
          value={draft}
          onChange={({ target: { value } }) => setDraft(value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
              event.preventDefault();
              addValue();
            }
          }}
        />
        <button
          disabled={disabled || !canAdd}
          type="button"
          className="btn btn-outline-primary whitespace-nowrap"
          onClick={addValue}
        >
          {addLabel}
        </button>
      </div>
    </div>
  );
};

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
  const sampling = config.sampling ?? defaultSamplingConfig();
  const unitPolicy = config.unitPolicy ?? { type: 'convertible_units', units: ['m/s'] };
  const variables = variableList(validation);
  const domains = syncDomains(validation.domains, variables);
  const [selectedVariable, setSelectedVariable] = useState(variables[0]);
  const [newVariable, setNewVariable] = useState('');
  const [variableError, setVariableError] = useState<string | undefined>();
  const [samplingOpen, setSamplingOpen] = useState(false);
  const selectedDomain = domainForVariable(domains, selectedVariable);

  useEffect(() => {
    if (!variables.includes(selectedVariable)) {
      setSelectedVariable(variables[0]);
    }
  }, [selectedVariable, variables]);

  const updateValidation = (nextValidation: MathExpressionQuestionConfig['validation']) =>
    onChange({ ...config, validation: nextValidation });

  const updateSampling = (update: Partial<SamplingConfig>) => {
    const nextSampling = {
      ...sampling,
      ...update,
    };

    onChange({
      ...config,
      sampling: {
        ...nextSampling,
        maxAttempts: Math.max(nextSampling.maxAttempts, nextSampling.desiredCount),
      },
    });
  };

  const setVariables = (nextVariables: string[], nextDomains = domains) => {
    const normalizedVariables = uniqueVariables(nextVariables);
    const effectiveVariables =
      normalizedVariables.length > 0 ? normalizedVariables : defaultVariables;
    updateValidation({
      ...validation,
      allowedVariables: effectiveVariables,
      domains: syncDomains(nextDomains, effectiveVariables),
    });
  };

  const addVariable = () => {
    const name = newVariable.trim();

    if (!isValidVariableName(name)) {
      setVariableError('Use one letter, such as x or t.');
      return;
    }

    if (variables.includes(name)) {
      setVariableError(`${name} is already allowed.`);
      return;
    }

    setVariableError(undefined);
    setNewVariable('');
    setSelectedVariable(name);
    setVariables([...variables, name], [...domains, defaultDomain(name)]);
  };

  const removeVariable = (name: string) => {
    const nextVariables = variables.filter((variable) => variable !== name);
    const effectiveVariables = nextVariables.length > 0 ? nextVariables : defaultVariables;
    setSelectedVariable(effectiveVariables[0]);
    setVariables(
      effectiveVariables,
      nextVariables.length > 0
        ? domains.filter((domain) => domain.name !== name)
        : [defaultDomain(defaultVariables[0])],
    );
  };

  const updateSelectedDomain = (update: Partial<VariableDomain>) => {
    updateValidation({
      ...validation,
      allowedVariables: variables,
      domains: domains.map((domain) =>
        domain.name === selectedVariable ? { ...domain, ...update } : domain,
      ),
    });
  };

  const variableSettings = variableConfigTypes.includes(questionType) ? (
    <div className={panelClassName}>
      <div className="mb-3 rounded border border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-800">
        <button
          type="button"
          className="flex w-full items-center justify-between px-3 py-2 text-left text-body-color dark:text-body-color-dark"
          aria-expanded={samplingOpen}
          onClick={() => setSamplingOpen(!samplingOpen)}
        >
          <span>
            <span className="block font-semibold">Sampling config</span>
            <span className={helpTextClassName}>
              Seed {sampling.seed}, {sampling.desiredCount} samples
            </span>
          </span>
          <ChevronDown
            className={`h-4 w-4 text-gray-600 transition-transform dark:text-gray-300 ${
              samplingOpen ? 'rotate-180' : ''
            }`}
            aria-hidden="true"
          />
        </button>
        {samplingOpen && (
          <div className="border-t border-gray-200 p-3 dark:border-gray-700">
            <p className={`${helpTextClassName} mb-3`}>
              These values make equivalence checks repeatable when variables are sampled.
            </p>
            <div className="d-flex flex-column flex-md-row gap-2">
              <label className="flex-1">
                <span className={smallLabelClassName}>Seed</span>
                <input
                  disabled={!editMode}
                  type="number"
                  step="1"
                  className={controlClassName}
                  aria-label="Sampling seed"
                  value={sampling.seed}
                  onChange={({ target: { value } }) => {
                    const parsed = parseFiniteInteger(value);
                    if (parsed === undefined) return;
                    updateSampling({ seed: parsed });
                  }}
                />
              </label>
              <label className="flex-1">
                <span className={smallLabelClassName}>Samples</span>
                <input
                  disabled={!editMode}
                  type="number"
                  min="1"
                  step="1"
                  className={controlClassName}
                  aria-label="Sample count"
                  value={sampling.desiredCount}
                  onChange={({ target: { value } }) => {
                    const parsed = parseFiniteInteger(value);
                    if (parsed === undefined || parsed < 1) return;
                    updateSampling({
                      desiredCount: parsed,
                      maxAttempts: Math.max(sampling.maxAttempts, parsed),
                    });
                  }}
                />
              </label>
              <label className="flex-1">
                <span className={smallLabelClassName}>Max attempts</span>
                <input
                  disabled={!editMode}
                  type="number"
                  min={sampling.desiredCount}
                  step="1"
                  className={controlClassName}
                  aria-label="Maximum sampling attempts"
                  value={sampling.maxAttempts}
                  onChange={({ target: { value } }) => {
                    const parsed = parseFiniteInteger(value);
                    if (parsed === undefined || parsed < sampling.desiredCount) return;
                    updateSampling({ maxAttempts: parsed });
                  }}
                />
              </label>
            </div>
            <label className="d-flex align-items-center mt-3 mb-0 text-body-color dark:text-body-color-dark">
              <input
                disabled={!editMode}
                type="checkbox"
                className="mr-1"
                checked={sampling.includeSpecialPoints}
                onChange={({ target: { checked } }) =>
                  updateSampling({ includeSpecialPoints: checked })
                }
              />
              Include special points
            </label>
          </div>
        )}
      </div>
      <div className="mb-3">
        <div className="form-label mb-1" style={{ fontWeight: 700 }}>
          Allowed variables
        </div>
        <p className={`${helpTextClassName} mb-0`}>
          These are the symbols students may use. The evaluator samples each selected variable from
          its domain when comparing equivalent expressions.
        </p>
      </div>
      <div className="d-flex flex-column flex-lg-row gap-3">
        <div className="w-100" style={{ maxWidth: 260 }}>
          <div className={smallLabelClassName}>Variables</div>
          <div className="mb-3 flex flex-col gap-2">
            {variables.map((variable) => (
              <div key={variable} className="d-flex gap-2">
                <button
                  type="button"
                  disabled={!editMode}
                  aria-pressed={selectedVariable === variable}
                  className={`flex min-h-[38px] flex-1 items-center justify-between rounded border px-3 py-2 text-left ${
                    selectedVariable === variable
                      ? 'border-blue-600 bg-blue-50 font-semibold text-blue-900 dark:border-blue-300 dark:bg-blue-900 dark:text-blue-100'
                      : 'border-gray-300 bg-white text-gray-900 dark:border-gray-600 dark:bg-body-dark dark:text-body-color-dark'
                  }`}
                  onClick={() => setSelectedVariable(variable)}
                >
                  <span>{variable}</span>
                </button>
                <button
                  type="button"
                  disabled={!editMode}
                  className="btn btn-link text-danger px-2"
                  aria-label={`Remove variable ${variable}`}
                  onClick={() => removeVariable(variable)}
                >
                  Remove
                </button>
              </div>
            ))}
          </div>
          <div className={smallLabelClassName}>Add variable</div>
          <div className="d-flex flex-column gap-2">
            <input
              disabled={!editMode}
              type="text"
              className={controlClassName}
              aria-label="New variable"
              value={newVariable}
              maxLength={1}
              onChange={({ target: { value } }) => {
                setNewVariable(value);
                setVariableError(undefined);
              }}
              onKeyDown={(event) => {
                if (event.key === 'Enter') {
                  event.preventDefault();
                  addVariable();
                }
              }}
            />
            <button
              disabled={!editMode}
              type="button"
              className="btn btn-outline-primary"
              onClick={addVariable}
            >
              Add variable
            </button>
            {variableError && (
              <div role="alert" className="text-sm text-red-700 dark:text-red-300">
                {variableError}
              </div>
            )}
          </div>
        </div>

        <div className="flex-1 rounded border border-gray-200 bg-gray-50 p-3 dark:border-gray-700 dark:bg-gray-800">
          <div className="mb-2 flex flex-wrap items-start justify-between gap-2">
            <div>
              <div className="text-base font-semibold text-gray-900 dark:text-gray-50">
                Variable {selectedVariable}
              </div>
              <p className={`${helpTextClassName} mb-0`}>
                {selectedVariable} will be sampled from {selectedDomain.lower.value} to{' '}
                {selectedDomain.upper.value}
                {(selectedDomain.exclusions ?? []).length > 0
                  ? `, excluding ${(selectedDomain.exclusions ?? []).join(', ')}`
                  : ''}
                .
              </p>
            </div>
          </div>

          <div className="mb-3 rounded border border-gray-200 bg-white p-3 dark:border-gray-700 dark:bg-body-dark">
            <div className={smallLabelClassName}>Domain</div>
            <p className={`${helpTextClassName} mb-2`}>
              The range of values used when checking whether the student expression is equivalent.
            </p>
            <div className="d-flex flex-column flex-md-row gap-2">
              <label className="flex-1">
                <span className={smallLabelClassName}>Min</span>
                <input
                  disabled={!editMode}
                  type="number"
                  className={controlClassName}
                  aria-label={`Minimum value for ${selectedVariable}`}
                  value={selectedDomain.lower.value}
                  onChange={({ target: { value } }) => {
                    const parsed = parseFiniteNumber(value);

                    if (parsed === undefined) return;

                    updateSelectedDomain({
                      lower: { ...selectedDomain.lower, value: parsed },
                    });
                  }}
                />
              </label>
              <label className="flex-1">
                <span className={smallLabelClassName}>Max</span>
                <input
                  disabled={!editMode}
                  type="number"
                  className={controlClassName}
                  aria-label={`Maximum value for ${selectedVariable}`}
                  value={selectedDomain.upper.value}
                  onChange={({ target: { value } }) => {
                    const parsed = parseFiniteNumber(value);

                    if (parsed === undefined) return;

                    updateSelectedDomain({
                      upper: { ...selectedDomain.upper, value: parsed },
                    });
                  }}
                />
              </label>
            </div>
            <div className="mt-2 flex flex-wrap gap-3">
              <label className="d-flex align-items-center mb-0">
                <input
                  disabled={!editMode}
                  type="checkbox"
                  className="mr-1"
                  checked={selectedDomain.lower.inclusive}
                  onChange={({ target: { checked } }) =>
                    updateSelectedDomain({
                      lower: { ...selectedDomain.lower, inclusive: checked },
                    })
                  }
                />
                Include min
              </label>
              <label className="d-flex align-items-center mb-0">
                <input
                  disabled={!editMode}
                  type="checkbox"
                  className="mr-1"
                  checked={selectedDomain.upper.inclusive}
                  onChange={({ target: { checked } }) =>
                    updateSelectedDomain({
                      upper: { ...selectedDomain.upper, inclusive: checked },
                    })
                  }
                />
                Include max
              </label>
              <label className="d-flex align-items-center mb-0">
                <input
                  disabled={!editMode}
                  type="checkbox"
                  className="mr-1"
                  checked={selectedDomain.integerOnly === true}
                  onChange={({ target: { checked } }) =>
                    updateSelectedDomain({ integerOnly: checked })
                  }
                />
                Integer values only
              </label>
            </div>
          </div>

          <div className="d-flex flex-column gap-3">
            <NumberListEditor
              disabled={!editMode}
              label="Excluded values"
              description="Values that should never be sampled, useful for avoiding undefined cases."
              values={selectedDomain.exclusions ?? []}
              addLabel="Add excluded value"
              inputLabel={`Excluded value for ${selectedVariable}`}
              onChange={(exclusions) => updateSelectedDomain({ exclusions })}
            />
            <NumberListEditor
              disabled={!editMode}
              label="Preferred values"
              description="Values the evaluator tries first before drawing more samples from the domain."
              values={selectedDomain.preferredValues ?? []}
              addLabel="Add preferred value"
              inputLabel={`Preferred value for ${selectedVariable}`}
              onChange={(preferredValues) => updateSelectedDomain({ preferredValues })}
            />
          </div>
        </div>
      </div>
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
