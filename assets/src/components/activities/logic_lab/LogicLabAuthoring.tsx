import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { Manifest } from '../types';
import { LabActivity, LogicLabModelSchema } from './LogicLabModelSchema';

const STORE = configureStore();

type LogicLabAuthoringProps = AuthoringElementProps<LogicLabModelSchema>;
/**
 * Authoring interface for LogicLab activities.
 * @component
 * @param props
 * @returns
 */
const Authoring: React.FC<LogicLabAuthoringProps> = (props: LogicLabAuthoringProps) => {
  const { dispatch, model } = useAuthoringElementContext<LogicLabModelSchema>();
  const [activityId, setActivityId] = useState<string>(props.model.activity);
  const [servlet, setServlet] = useState<string>(props.model.src);
  useEffect(() => {
    setActivityId(model.activity);
    setServlet(model.src);
  }, [model]);

  //const guid = useId(); // Needs react ^18
  const [id] = useState<string>(crypto.randomUUID());
  const [includeArgument, setIncludeArgument] = useState<boolean>(true);
  const [includeParse, setIncludeParse] = useState(true);
  const [includeDerivation, setIncludeDerivation] = useState(true);
  const [includeChase, setIncludeChase] = useState(true);
  const [includeTable, setIncludeTable] = useState(true);
  const [includeTree, setIncludeTree] = useState(true);
  const [includeSet, setIncludeSet] = useState(false);
  const [activities, setActivities] = useState<LabActivity[]>([]);
  const allowSets = false; // sets not quite supported in lab

  useEffect(() => {
    const getActivities = async () => {
      // url should be relative to model.src, but is static for development.
      const response = await fetch('http://localhost:8080/api/v1/activities');
      if (!response.ok) throw new Error(response.statusText);
      const problems = (await response.json()) as LabActivity[];
      problems.sort((a, b) =>
        [...a.keywords, a.id].join('/').localeCompare([...b.keywords, b.id].join('/')),
      );
      setActivities(problems);
    };
    getActivities().catch(console.error);
  }, []);

  return (
    <form>
      <h3>LogicLab Activity Selection</h3>
      <div className="form-group">
        <label>{/* Needed for development, to be removed when servlet is publicly hosted somewhere. */}
          AProS Servlet url:
        <input type="text" value={servlet} onChange={(e) => setServlet(e.target.value)} />
        </label>
        <div className="flex items-baseline gap-2">
          <span>Activity&nbsp;Types:</span>
          <div className="flex items-center">
            <input
              id={`$id_filter_argument`}
              type="checkbox"
              checked={includeArgument}
              onChange={(e) => setIncludeArgument(e.target.checked)}
            />
            <label htmlFor={`$id_filter_argument`} className="mx-2 text-sm">
              Argument&nbsp;Diagrams
            </label>
          </div>
          <div className="flex items-center">
            <input
              id={`$id_filter_chase`}
              type="checkbox"
              checked={includeChase}
              onChange={(e) => setIncludeChase(e.target.checked)}
            />
            <label htmlFor={`$id_filter_chase`} className="ms-2 text-sm">
              Chasing&nbsp;Truth
            </label>
          </div>
          <div className="flex items-center">
            <input
              id={`$id_filter_derivation`}
              type="checkbox"
              checked={includeDerivation}
              onChange={(e) => setIncludeDerivation(e.target.checked)}
            />
            <label htmlFor={`$id_filter_derivation`} className="ms-2 text-sm">
              Derivations
            </label>
          </div>
          <div className="flex items-center">
            <input
              id={`$id_filter_parse`}
              type="checkbox"
              checked={includeParse}
              onChange={(e) => setIncludeParse(e.target.checked)}
            />
            <label htmlFor={`$id_filter_parse`} className="ms-2 text-sm">
              Parse&nbsp;Trees
            </label>
          </div>
          <div className="flex items-center">
            <input
              id={`$id_filter_table`}
              type="checkbox"
              checked={includeTable}
              onChange={(e) => setIncludeTable(e.target.checked)}
            />
            <label htmlFor={`$id_filter_table`} className="ms-2 text-sm">
              Truth&nbsp;Tables
            </label>
          </div>
          <div className="flex items-center">
            <input
              id={`$id_filter_tree`}
              type="checkbox"
              checked={includeTree}
              onChange={(e) => setIncludeTree(e.target.checked)}
            />
            <label htmlFor={`$id_filter_tree`} className="ms-2 text-sm">
              Truth&nbsp;Trees
            </label>
          </div>
          {allowSets && (
            <div className="flex items-center">
              <input
                id={`$id_filter_set`}
                type="checkbox"
                checked={includeSet}
                onChange={(e) => setIncludeSet(e.target.checked)}
              />
              <label htmlFor={`$id_filter_set`} className="ms-2 text-sm">
                Activity&nbsp;Set
              </label>
            </div>
          )}
        </div>
        <label htmlFor={id}>Select activity</label>
        <select
          id={id}
          value={activityId}
          onChange={(e) => {
            dispatch((draft, _post) => {
              draft.activity = e.target.value;
            });
          }}
        >
          <option>---</option>
          {activities
            .filter((p) => {
              switch (p.spec.type) {
                case 'parse_tree':
                  return includeParse;
                case 'derivation':
                  return includeDerivation;
                case 'chase_truth':
                  return includeChase;
                case 'truth_table':
                  return includeTable;
                case 'truth_tree':
                  return includeTree;
                case 'argument_diagram':
                  return includeArgument;
                case 'activities':
                  return includeSet;
                default:
                  return true;
              }
            })
            .map((p) => (
              <option key={p.id} value={p.id}>
                {p.title}({p.spec.type}) [{p.keywords.join('/')}/{p.id}]
              </option>
            ))}
        </select>
      </div>
    </form>
  );
};

/**
 * Torus authoring component for LogicLab activities.
 * @component
 */
export class LogicLabAuthoring extends AuthoringElement<LogicLabModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<LogicLabModelSchema>): void {
    ReactDOM.render(
      <Provider store={STORE}>
        <AuthoringElementProvider {...props}>
          <Authoring {...props} />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// eslint-disable-next-line @typescript-eslint/no-var-requires
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, LogicLabAuthoring);
