import { CapiVariable, CapiVariableTypes } from 'adaptivity/capi';
import {
  applyState,
  ApplyStateOperation,
  evalScript,
  getAssignScript,
  getValue,
  getExpressionStringForValue,
  looksLikeJson,
} from 'adaptivity/scripting';
import { Environment } from 'janus-script';

describe('Scripting Interface', () => {
  describe('looksLikeJson', () => {
    it('should return true for a valid json string', () => {
      expect(looksLikeJson('{ "a": 1 }')).toBe(true);
    });
    it('should return false for an invalid json string', () => {
      expect(looksLikeJson('{ a: 1 }')).toBe(false);
    });
    it('should return true for the config from FIB', () => {
      const jsonVal =
        '{"content":{"ops":[{"insert":"An eclipse happens when "},{"insert":{"dropdown":{"id":"dropdown-aac4d92a-c396-46e6-a0df-358afc3824b2"}}},{"insert":" blocks&#xa;sunlight from reaching another celestial body, &#xa;"},{"insert":{"dropdown":{"id":"dropdown-66aa9663-d1c9-418c-abac-942387472141"}}},{"insert":".&#xa;"}]},"dropdowns":{"dropdown-aac4d92a-c396-46e6-a0df-358afc3824b2":{"correct":"option8","options":{"option6":"the Sun","option7":"a dragon","option8":"a celestial body","option9":"Earth","option10":"the Moon"}},"dropdown-66aa9663-d1c9-418c-abac-942387472141":{"correct":"option2","options":{"option1":"destroying the Sun","option2":"casting a shadow","option3":"eating the Sun","option4":"destroying the Moon"}}},"textInputs":{}}';

      expect(looksLikeJson(jsonVal)).toBe(true);
    });
  });

  describe('ApplyState', () => {
    it('should support the adding and + operator', () => {
      const env = new Environment();
      evalScript('let x = 1;', env);
      const applyOperation: ApplyStateOperation = {
        target: 'x',
        operator: 'adding',
        value: 2,
      };
      applyState(applyOperation, env);
      const x = getValue('x', env);
      expect(x).toBe(3);
      applyOperation.operator = '+';
      applyState(applyOperation, env);
      const y = getValue('x', env);
      expect(y).toBe(5);
    });

    it('should support the subtracting and - operator', () => {
      const env = new Environment();
      evalScript('let x = 10;', env);
      const applyOperation: ApplyStateOperation = {
        target: 'x',
        operator: 'subtracting',
        value: 2,
      };
      applyState(applyOperation, env);
      const x = getValue('x', env);
      expect(x).toBe(8);
      applyOperation.operator = '-';
      applyState(applyOperation, env);
      const y = getValue('x', env);
      expect(y).toBe(6);
    });

    it('should support assignment of Enum types', () => {
      const env = new Environment();
      evalScript('let x = "A";', env);
      const applyOperation: ApplyStateOperation = {
        target: 'x',
        operator: '=',
        value: 'B',
        type: CapiVariableTypes.ENUM,
      };
      applyState(applyOperation, env);
      const x = getValue('x', env);
      expect(x).toBe('B');
    });

    it('should support assignment of expressions', () => {
      const env = new Environment();
      evalScript('let x = 1;let y = 2;let {session.currentQuestionScore} = 50;', env);
      const applyOperation: ApplyStateOperation = {
        target: 'x',
        operator: '=',
        value: '{x} + {y} + 1',
        type: CapiVariableTypes.NUMBER,
      };
      applyState(applyOperation, env);
      const x = getValue('x', env);
      expect(x).toBe(4);
      const applyOperation1: ApplyStateOperation = {
        target: 'y',
        operator: '=',
        value: '100 - {session.currentQuestionScore}',
        type: CapiVariableTypes.NUMBER,
      };
      applyState(applyOperation1, env);
      const y = getValue('y', env);
      expect(y).toBe(50);
    });

    it('should support addition of expressions', () => {
      const env = new Environment();
      evalScript('let x = 1;let y = 2;let {session.currentQuestionScore} = 50;', env);
      const applyOperation: ApplyStateOperation = {
        target: 'x',
        operator: 'adding',
        value: '{session.currentQuestionScore}',
        type: CapiVariableTypes.NUMBER,
      };
      applyState(applyOperation, env);
      const x = getValue('x', env);
      expect(x).toBe(51);
      const applyOperation1: ApplyStateOperation = {
        target: 'y',
        operator: 'adding',
        value: '100 - {x}',
        type: CapiVariableTypes.NUMBER,
      };
      applyState(applyOperation1, env);
      const y = getValue('y', env);
      expect(y).toBe(51);
    });

    it('should support subtraction of expressions', () => {
      const env = new Environment();
      evalScript('let x = 1;let y = 2;let {session.currentQuestionScore} = 50;', env);
      const applyOperation: ApplyStateOperation = {
        target: 'x',
        operator: 'subtracting',
        value: '{session.currentQuestionScore}',
        type: CapiVariableTypes.NUMBER,
      };
      applyState(applyOperation, env);
      const x = getValue('x', env);
      expect(x).toBe(-49);
      const applyOperation1: ApplyStateOperation = {
        target: 'y',
        operator: 'subtracting',
        value: '100 - {x}',
        type: CapiVariableTypes.NUMBER,
      };
      applyState(applyOperation1, env);
      const y = getValue('y', env);
      expect(y).toBe(-49);
    });

    it('should support the "bind to" operator', () => {
      const env = new Environment();
      evalScript('let x = 1;let {session.currentQuestionScore} = 50;', env);
      const applyOperation: ApplyStateOperation = {
        target: 'x',
        operator: 'bind to',
        value: 'session.currentQuestionScore',
        type: CapiVariableTypes.NUMBER,
      };
      applyState(applyOperation, env);
      let x = getValue('x', env);
      expect(x).toBe(50);
      evalScript('let {session.currentQuestionScore} = 75;', env);
      x = getValue('x', env);
      expect(x).toBe(75);
    });
  });

  describe('getValue', () => {
    it('should get the direct value for a scripting variable', () => {
      const environment = new Environment();
      evalScript('let x = "42";', environment);

      const value = getValue('x', environment);
      expect(value).toBe('42');
    });
  });

  describe('evalScript', () => {
    it('should return a reference to the environment', () => {
      const environment = new Environment();
      const result = evalScript('let x = "42";', environment);
      expect(result.env).toBe(environment);
    });
  });

  describe('getAssignScript', () => {
    it('should return a script that assigns a value to a variable', () => {
      const environment = new Environment();
      const script = getAssignScript({ x: 42 });
      const result = evalScript(script, environment);
      const value = getValue('x', environment);
      expect(script).toBe('let {x} = 42;');
      expect(result.result).toBe(null);
      expect(value).toBe(42);
    });

    it('should assign CSS values as strings', () => {
      const environment = new Environment();
      const varValue =
        'let a = body[data-new-gr-c-s-check-loaded] #scene_Student{border-radius:3px;border:solid 1px #484848 !important;background-color: #161616;padding: 10px;box-sizing: border-box;}.columns-container {padding: 0;}.columns-container .items-column .item:last-child {margin-bottom: 0;}.container {overflow: hidden;}.items-column {height: 100%;}.items-column .items-container {height: 100%;display: flex;flex-direction: column;justify-content: space-between;}.columns-container .items-column .item {border: solid 0.5px #FFC627;background-color: black;padding: 10px;box-sizing: border-box;height: 40px;margin-bottom: 5px;height: 75px;}.item.link-hover {padding: 10px;}.columns-container .items-column .item .item-label {color: #ffffff;height: auto;position: relative;top: 50%;transform: translateY(calc(-50% + 4px));line-height:initial;}.columns-container .left-column .item {border-radius: 4px 100px 100px 4px;margin-left: 0;}.columns-container .left-column .item .item-label:after {content: "";width: 20px;height: 20px;box-sizing: border-box;position: absolute;background-color: transparent;border: solid 1px #FFC627;border-radius: 100px;margin: 0;padding: 0;top: 50%;transform: translateY(-50%);right: 5px;}.columns-container .right-column .item {border-radius: 100px 4px 4px 100px;margin-right: 0;}.columns-container .right-column .item .item-label:after {content: "";width: 20px;height: 20px;box-sizing: border-box;position: absolute;background-color: transparent;border: solid 1px #FFC627;border-radius: 100px;margin: 0;padding: 0;top: 50%;transform: translateY(-50%);left: 5px;}.columns-container .items-column .item.link-hover {border: solid 1px #FFC627;background-color: #222;padding: 0;box-sizing: border-box;box-shadow: none;}.columns-container .items-column .item[linked] {border: solid 2px #FFC627;background-color: #291b30;box-shadow: none;}.columns-container .items-column .item.preview-source-hover, .columns-container .items-column .item.preview-target-hover {border: solid 3px #ffcc00;background-color: #291b30;box-shadow: none;}.columns-container .items-column .item .remove-links:before {content: "X";margin-left: auto;margin-right: auto;position: relative;}.line-renderer line {stroke: #FFC627;stroke-width: 2px;}.line-renderer line.pointer {stroke: #ffcc00;stroke-width: 2px;}';
      const script = getAssignScript({
        x: {
          key: 'Custom CSS',
          path: 'stage.x',
          value: varValue,
        },
      });
      const result = evalScript(script, environment);
      const value = getValue('stage.x', environment);
      expect(result.result).toBe(null);
      expect(value).toBe(varValue);
    });

    it('should assign variable expression value and calculate the expression', () => {
      const environment = new Environment();
      evalScript(
        'let {stage.vft.Score} = 1;let {stage.vft.Map complete}=0;let {session.tutorialScore}=0',
        environment,
      );
      const varValue =
        '{stage.vft.Score}*70 + {stage.vft.Map complete}*100 - {session.tutorialScore}';
      const script = getAssignScript({
        x: {
          key: 'score',
          path: 'stage.x',
          value: varValue,
        },
      });
      const result = evalScript(script, environment);
      const value = getValue('stage.x', environment);
      expect(result.result).toBe(null);
      expect(script).toBe(`let {stage.x} = ${varValue};`);
      expect(value).toBe(70);
    });

    it('should return an assignment script from a capi-like variable', () => {
      const environment = new Environment();
      const script = getAssignScript({ x: { key: 'x', path: 'stage.x', value: 42 } });
      const result = evalScript(script, environment);
      const value = getValue('stage.x', environment);
      expect(script).toBe('let {stage.x} = 42;');
      expect(result.result).toBe(null);
      expect(value).toBe(42);
    });

    it('should assign JSON values as strings', () => {
      const environment = new Environment();
      const script = getAssignScript({
        x: {
          type: CapiVariableTypes.STRING,
          key: 'x',
          path: 'stage.x',
          value: '{"a":"something"}',
        },
      });
      const result = evalScript(script, environment);
      const value = getValue('stage.x', environment);
      expect(script).toBe(`let {stage.x} = "{\\"a\\":\\"something\\"}";`);
      expect(result.result).toBe(null);
      expect(value).toBe('{"a":"something"}');
    });

    it('should assign empty JSON values as strings', () => {
      const environment = new Environment();
      const script = getAssignScript({
        x: { type: CapiVariableTypes.STRING, key: 'x', path: 'stage.x', value: '{}' },
      });
      const result = evalScript(script, environment);
      const value = getValue('stage.x', environment);
      expect(script).toBe(`let {stage.x} = "{}";`);
      expect(result.result).toBe(null);
      expect(value).toBe('{}');
    });
  });

  describe('getExpressionStringForValue', () => {
    it('should return a script that assigns a value to a variable', () => {
      const variable = {
        type: CapiVariableTypes.STRING,
        key: 'x',
        value: 'foo',
      };
      const script = getExpressionStringForValue(variable);
      expect(script).toBe('"foo"');
    });

    it('should allow janus-script variables to be assigned', () => {
      const variable = {
        type: CapiVariableTypes.STRING,
        key: 'x',
        value: '{q:1541204522672:818|stage.FillInTheBlanks.Input 1.Value}',
      };
      const script = getExpressionStringForValue(variable);
      expect(script).toBe('{q:1541204522672:818|stage.FillInTheBlanks.Input 1.Value}');
    });

    it('should allow full janus-script expressions to be assigned', () => {
      const variable = {
        type: CapiVariableTypes.STRING,
        key: 'x',
        value: '{stage.foo} + {stage.bar}',
      };
      const variable1 = {
        type: CapiVariableTypes.STRING,
        key: 'x',
        value: '{stage.vft.Score}*70 + {stage.vft.Map complete}*100 - {session.tutorialScore}',
      };
      const variable2 = {
        type: CapiVariableTypes.STRING,
        key: 'x',
        value: '100 - {session.currentQuestionScore}',
      };
      const variable3 = {
        type: CapiVariableTypes.NUMBER,
        key: 'x',
        value: 'round({stage.foo.something})',
      };
      const variable4 = {
        type: CapiVariableTypes.ARRAY,
        key: 'x',
        value:
          '[{e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 1},{e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 2}]',
      };
      const variable5 = {
        type: CapiVariableTypes.ARRAY,
        key: 'x',
        value:
          '{e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 1},{e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 2}',
      };
      const variable6 = {
        type: CapiVariableTypes.ARRAY,
        key: 'x',
        value: '[1,2,3,4,5]',
      };
      let script = getExpressionStringForValue(variable);
      expect(script).toBe('{stage.foo} + {stage.bar}');
      script = getExpressionStringForValue(variable1);
      expect(script).toBe(
        '{stage.vft.Score}*70 + {stage.vft.Map complete}*100 - {session.tutorialScore}',
      );
      script = getExpressionStringForValue(variable2);
      expect(script).toBe('100 - {session.currentQuestionScore}');
      script = getExpressionStringForValue(variable3);
      expect(script).toBe('round({stage.foo.something})');
      script = getExpressionStringForValue(variable4);
      expect(script).toBe(
        '[{e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 1},{e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 2}]',
      );
      script = getExpressionStringForValue(variable5);
      expect(script).toBe(
        '[{e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 1},{e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 2}]',
      );
      script = getExpressionStringForValue(variable6);
      expect(script).toBe('[1,2,3,4,5]');
    });

    it('should assign numbers based on type', () => {
      const variable = {
        type: CapiVariableTypes.NUMBER,
        key: 'x',
        value: 5,
      };
      const variable1 = {
        type: CapiVariableTypes.NUMBER,
        key: 'x',
        value: '5',
      };
      let script = getExpressionStringForValue(variable);
      expect(script).toBe('5');
      script = getExpressionStringForValue(variable1);
      expect(script).toBe('5');
    });

    it('should wrap all strings in quotes', () => {
      const variable = {
        type: CapiVariableTypes.STRING,
        key: 'x',
        value: 'foo',
      };
      const variable1 = {
        type: CapiVariableTypes.ENUM,
        key: 'x',
        value: 'TEST',
      };
      const variable2 = {
        type: CapiVariableTypes.MATH_EXPR,
        key: 'x',
        value: 'x + 1 = 3',
      };
      const variable3 = {
        type: CapiVariableTypes.UNKNOWN,
        key: 'x',
        value: 'foo',
      };
      let script = getExpressionStringForValue(variable);
      expect(script).toBe('"foo"');
      script = getExpressionStringForValue(variable1);
      expect(script).toBe('"TEST"');
      script = getExpressionStringForValue(variable2);
      expect(script).toBe('"x + 1 = 3"');
      script = getExpressionStringForValue(variable3);
      expect(script).toBe('"foo"');
    });

    it('should deal with JSON values', () => {
      const jsonVal = '{"content":{"ops":[1, 2, 3]}}';
      const escapedVal = '{\\"content\\":{\\"ops\\":[1, 2, 3]}}';
      const variable = {
        type: 2,
        value: jsonVal,
      };
      const script = getExpressionStringForValue(variable);
      expect(script).toBe(`"${escapedVal}"`);
    });

    it('should deal with CSS that looks like expressions', () => {
      const cssVal =
        '@font-face{font-family:PTSerif;src:url(https://dev-etx.ws.asu.edu/fonts/PT%20Serif/PT_Serif-Web.ttf)}';
      const variable = {
        type: CapiVariableTypes.STRING,
        value: cssVal,
      };
      const script = getExpressionStringForValue(variable);
      expect(script).toBe(`"${cssVal}"`);
    });

    it('should handle Arrays', () => {
      const variable = {
        type: CapiVariableTypes.ARRAY,
        key: 'x',
        value: [1, 2, 3],
      };
      const variable1 = {
        type: CapiVariableTypes.ARRAY,
        key: 'x',
        value: '[1,2,3]',
      };
      let script = getExpressionStringForValue(variable);
      expect(script).toBe('[1,2,3]');
      script = getExpressionStringForValue(variable1);
      expect(script).toBe('[1,2,3]');
    });

    it('should handle boolean values', () => {
      const variable = {
        type: CapiVariableTypes.BOOLEAN,
        key: 'x',
        value: true,
      };
      const variable1 = {
        type: CapiVariableTypes.BOOLEAN,
        key: 'x',
        value: 'true',
      };
      const variable2 = {
        type: CapiVariableTypes.BOOLEAN,
        key: 'x',
        value: 'false',
      };
      const variable3 = {
        type: CapiVariableTypes.BOOLEAN,
        key: 'x',
        value: 1,
      };
      const variable4 = {
        type: CapiVariableTypes.BOOLEAN,
        key: 'x',
        value: 0,
      };
      const variable5 = {
        type: CapiVariableTypes.BOOLEAN,
        key: 'x',
        value: '1',
      };
      const variable6 = {
        type: CapiVariableTypes.BOOLEAN,
        key: 'x',
        value: '0',
      };
      let script = getExpressionStringForValue(variable);
      expect(script).toBe('true');
      script = getExpressionStringForValue(variable1);
      expect(script).toBe('true');
      script = getExpressionStringForValue(variable2);
      expect(script).toBe('false');
      script = getExpressionStringForValue(variable3);
      expect(script).toBe('true');
      script = getExpressionStringForValue(variable4);
      expect(script).toBe('false');
      script = getExpressionStringForValue(variable5);
      expect(script).toBe('true');
      script = getExpressionStringForValue(variable6);
      expect(script).toBe('false');
    });
  });
});
