import { CapiVariableTypes } from 'adaptivity/capi';
import { janus_std } from 'adaptivity/janus-scripts/builtin_functions';
import {
  applyState,
  ApplyStateOperation,
  checkExpressionsWithWrongBrackets,
  evalScript,
  extractUniqueVariablesFromText,
  getAssignScript,
  getExpressionStringForValue,
  getValue,
  looksLikeJson,
  templatizeText,
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

    it('should not return result errors rather than throw them', () => {
      const env = new Environment();
      evalScript('let x = 1;', env);
      const applyOperation: ApplyStateOperation = {
        target: 'x',
        operator: '',
        value: 7,
        type: CapiVariableTypes.NUMBER,
      };
      const { result } = applyState(applyOperation, env);
      expect(result.error).toEqual(true);
    });

    it('should trim target variables to prevent errors', () => {
      const env = new Environment();
      evalScript('let x = 1;', env);
      const applyOperation: ApplyStateOperation = {
        target: ' x',
        operator: '+',
        value: 7,
        type: CapiVariableTypes.NUMBER,
      };
      const { result } = applyState(applyOperation, env);
      expect(result).toEqual(null);
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
      const script = getAssignScript({ x: 42 }, environment);
      const result = evalScript(script, environment);
      const value = getValue('x', environment);
      expect(script).toBe('let {x} = 42;');
      expect(result.result).toBe(null);
      expect(value).toBe(42);
    });

    it('it should correctly detect CSS and should be working for most of the CSS values', () => {
      const environment = new Environment();
      const varValueFormat1 =
        'body[data-new-gr-c-s-check-loaded] #scene_Student{border-radius:3px;border:solid 1px #484848 !important;background-color: #161616;padding: 10px;box-sizing: border-box;}.columns-container {padding: 0;}.columns-container .items-column .item:last-child {margin-bottom: 0;}.container {overflow: hidden;}.items-column {height: 100%;}.items-column .items-container {height: 100%;display: flex;flex-direction: column;justify-content: space-between;}.columns-container .items-column .item {border: solid 0.5px #FFC627;background-color: black;padding: 10px;box-sizing: border-box;height: 40px;margin-bottom: 5px;height: 75px;}.item.link-hover {padding: 10px;}.columns-container .items-column .item .item-label {color: #ffffff;height: auto;position: relative;top: 50%;transform: translateY(calc(-50% + 4px));line-height:initial;}.columns-container .left-column .item {border-radius: 4px 100px 100px 4px;margin-left: 0;}.columns-container .left-column .item .item-label:after {content: "";width: 20px;height: 20px;box-sizing: border-box;position: absolute;background-color: transparent;border: solid 1px #FFC627;border-radius: 100px;margin: 0;padding: 0;top: 50%;transform: translateY(-50%);right: 5px;}.columns-container .right-column .item {border-radius: 100px 4px 4px 100px;margin-right: 0;}.columns-container .right-column .item .item-label:after {content: "";width: 20px;height: 20px;box-sizing: border-box;position: absolute;background-color: transparent;border: solid 1px #FFC627;border-radius: 100px;margin: 0;padding: 0;top: 50%;transform: translateY(-50%);left: 5px;}.columns-container .items-column .item.link-hover {border: solid 1px #FFC627;background-color: #222;padding: 0;box-sizing: border-box;box-shadow: none;}.columns-container .items-column .item[linked] {border: solid 2px #FFC627;background-color: #291b30;box-shadow: none;}.columns-container .items-column .item.preview-source-hover, .columns-container .items-column .item.preview-target-hover {border: solid 3px #ffcc00;background-color: #291b30;box-shadow: none;}.columns-container .items-column .item .remove-links:before {content: "X";margin-left: auto;margin-right: auto;position: relative;}.line-renderer line {stroke: #FFC627;stroke-width: 2px;}.line-renderer line.pointer {stroke: #ffcc00;stroke-width: 2px;}';
      const varValueFormat2 =
        'body[data-new-gr-c-s-check-loaded] #scene_Student{border-radius:3px;border:solid 1px #484848!important;background-color:#161616;padding:10px;box-sizing:border-box}.columns-container{padding:0}.columns-container .items-column .item:last-child{margin-bottom:0}.container{overflow:hidden}.items-column{height:100%}.items-column .items-container{height:100%}.columns-container .items-column .item{border:solid .5px #ffc627;background-color:#000;padding:10px;box-sizing:border-box;height:40px;margin-bottom:5px;height:75px}.item.link-hover{padding:10px}.columns-container .items-column .item .item-label{color:#fff;height:auto;position:relative;top:50%;transform:translateY(calc(-50% + 4px));line-height:initial}.columns-container .left-column .item{border-radius:4px 100px 100px 4px;margin-left:0}.columns-container .left-column .item .item-label:after{content:"";width:20px;height:20px;box-sizing:border-box;position:absolute;background-color:transparent;border:solid 1px #ffc627;border-radius:100px;margin:0;padding:0;top:50%;transform:translateY(-50%);right:5px}.columns-container .right-column .item{border-radius:100px 4px 4px 100px;margin-right:0}.columns-container .right-column .item .item-label:after{content:"";width:20px;height:20px;box-sizing:border-box;position:absolute;background-color:transparent;border:solid 1px #ffc627;border-radius:100px;margin:0;padding:0;top:50%;transform:translateY(-50%);left:5px}.columns-container .items-column .item.link-hover{border:solid 1px #ffc627;background-color:rgba(0,0,0,.2);padding:0;box-sizing:border-box;box-shadow:none}.columns-container .items-column .item[linked]{border:solid 2px #ffc627;background-color:#291b30;box-shadow:none}.columns-container .items-column .item.preview-source-hover,.columns-container .items-column .item.preview-target-hover{border:solid 3px #fc0;background-color:#291b30;box-shadow:none}.columns-container .items-column .item .remove-links:before{content:"X";margin-left:auto;margin-right:auto;position:relative}.line-renderer line{stroke:#ffc627;stroke-width:2px}.line-renderer line.pointer{stroke:#fc0;stroke-width:2px}';

      const script = getAssignScript(
        {
          x: {
            key: 'Custom CSS',
            path: 'stage.x',
            value: varValueFormat1,
          },
          y: {
            key: 'Custom CSS',
            path: 'stage.y',
            value: varValueFormat2,
          },
        },
        environment,
      );
      const result = evalScript(script, environment);
      const valuex = getValue('stage.x', environment);
      const valuey = getValue('stage.y', environment);
      expect(result.result).toBe(null);
      expect(valuex).toBe(varValueFormat1);
      expect(valuey).toBe(varValueFormat2);
    });

    it('should return the CSS as it is', () => {
      const environment = new Environment();
      let text =
        '@font-face{font-family:PTSerif;src:url(https://dev-etx.ws.asu.edu/fonts/PT%20Serif/PT_Serif-Web-Regular.ttf)}.button{white-space:normal;font-family:PTSerif,Georgia,serif;font-size:16px;font-weight:700;text-transform:none;line-height:120%;color:#E7A96B;width:calc(100% - 2px);height:auto!important;background-color:#484848;background-image:linear-gradient(rgba(0,0,0,0),rgba(0,0,0,.6));border-radius:3px;border:none;-moz-box-shadow:2px 2px rgba(0,0,0,.2);-webkit-box-shadow:2px 2px rgba(0,0,0,.2);box-shadow:2px 2px rgba(0,0,0,.2);padding:10px 20px;cursor:pointer}.button:active,.button:focus,.button:hover{background-color:#5C5C5C!important;background-image:linear-gradient(rgba(0,0,0,0),rgba(0,0,0,.6))}.button:focus,.button:hover{-moz-box-shadow:2px 2px rgba(0,0,0,.2);-webkit-box-shadow:2px 2px rgba(0,0,0,.2);box-shadow:2px 2px rgba(0,0,0,.2)}.button:active{-moz-box-shadow:inset 0 2px rgba(0,0,0,.4);-webkit-box-shadow:inset 0 2px rgba(0,0,0,.4);box-shadow:inset 0 2px rgba(0,0,0,.4);transform:translateY(1px);color:#E7A96B!important}.button:disabled{background-color:#858585;cursor:default}.button:disabled:active{-moz-box-	shadow:inset 0 0 transparent;-webkit-box-shadow:inset 0 0 transparent;box-shadow:inset 0 0 transparent;color:rgba(255,255,255,.9);transform:translateY(0)}';
      let result = templatizeText(text, environment);
      expect(result).toBe(text);

      text = 'stage.foo.value =  {stage.foo.value}; stage.foo1.value =  {stage.foo1.value};';
      evalScript(
        'let {stage.foo.value} = 1;let {stage.foo1.value}=80;let {stage.foo2.value}=50',
        environment,
      );
      result = templatizeText(text, environment, environment);
      expect(result).toBe('stage.foo.value =  1; stage.foo1.value =  80;');

      text = 'Lets try with variables {variables.foo}';
      evalScript('let {variables.foo} = 0.52', environment);
      result = templatizeText(text, environment, environment);
      expect(result).toBe('Lets try with variables 0.52');

      text = 'Lets try with variables {variables.foo';
      result = templatizeText(text, environment);
      expect(result).toBe(text);

      const script = getAssignScript(
        {
          x: {
            key: 'variables.UnknownBeaker',
            path: '',
            value: [1],
          },
        },
        environment,
      );

      evalScript(script, environment);
      text = '{variables.UnknownBeaker}';
      result = templatizeText(text, environment, environment);
      expect(result).toBe('"1"');

      text = 'The values is {variables.UnknownBeaker}';
      result = templatizeText(text, environment, environment);
      expect(result).toBe('The values is "1"');
    });

    it('should be able to templatizeText with any expression in the string', () => {
      const environment = new Environment();
      // load the built in functions
      evalScript(janus_std, environment);

      const populateScript = getAssignScript(
        {
          x: {
            key: 'variables.star_flux1',
            path: '',
            value: 1000000,
          },
        },
        environment,
      );

      evalScript(populateScript, environment);

      let text = '{roundSF(variables.star_flux1, 1)}';
      let result = templatizeText(text, {}, environment);
      expect(result).toBe('1e+6');

      text = '{min(10, 20)}';
      result = templatizeText(text, {}, environment);
      expect(result).toBe('10');

      text = '{max(10, 20) + 1}';
      result = templatizeText(text, {}, environment);
      expect(result).toBe('21');
    });

    it('should be able to templatizeText of math expressions', () => {
      const expr1 = '16^{\\frac{1}{2}}=\\sqrt {16}={\\editable{}}';
      const expr2 = '2\\times\\frac{3}{2}=\\editable{}';
      const env = new Environment();
      const result = templatizeText(expr1, env);
      expect(result).toEqual(expr1);
      const result2 = templatizeText(expr2, env);
      expect(result2).toEqual(expr2);
    });

    it('it should return math expression as it is', () => {
      const environment = new Environment();
      const mathExpr1 = '2\\times\\frac{3}{2}=\\editable{}';
      const mathExpr2 = '16^{\\frac{1}{2}}=\\sqrt {16}={\\editable{}}';

      const script = getAssignScript(
        {
          x: {
            key: 'Math Expression',
            path: 'stage.x',
            value: mathExpr1,
          },
        },
        environment,
      );
      const result = evalScript(script, environment);
      const valuex = getValue('stage.x', environment);
      expect(result.result).toBe(null);
      expect(valuex).toBe(mathExpr1);

      const script2 = `let {stage.x} = "${mathExpr2}";`;
      const result2 = evalScript(script2, environment);
      const valuex2 = getValue('stage.x', environment);
      expect(result2.result).toBe(null);
      expect(valuex2).toBe(mathExpr2);
    });

    it('should assign variable expression value and calculate the expression', () => {
      const environment = new Environment();
      evalScript(
        'let {stage.vft.Score} = 1;let {stage.vft.Map complete}=0;let {session.tutorialScore}=0',
        environment,
      );
      const varValue =
        '{stage.vft.Score}*70 + {stage.vft.Map complete}*100 - {session.tutorialScore}';
      const script = getAssignScript(
        {
          x: {
            key: 'score',
            path: 'stage.x',
            value: varValue,
          },
        },
        environment,
      );
      const result = evalScript(script, environment);
      const value = getValue('stage.x', environment);
      expect(result.result).toBe(null);
      expect(script).toBe(`let {stage.x} = ${varValue};`);
      expect(value).toBe(70);
    });

    it('should return an assignment script from a capi-like variable', () => {
      const environment = new Environment();
      const script = getAssignScript({ x: { key: 'x', path: 'stage.x', value: 42 } }, environment);
      const result = evalScript(script, environment);
      const value = getValue('stage.x', environment);
      expect(script).toBe('let {stage.x} = 42;');
      expect(result.result).toBe(null);
      expect(value).toBe(42);
    });

    it('should assign JSON values as strings', () => {
      const environment = new Environment();
      const script = getAssignScript(
        {
          x: {
            type: CapiVariableTypes.STRING,
            key: 'x',
            path: 'stage.x',
            value: '{"a":"something"}',
          },
        },
        environment,
      );
      const result = evalScript(script, environment);
      const value = getValue('stage.x', environment);
      expect(script).toBe(`let {stage.x} = "{\\"a\\":\\"something\\"}";`);
      expect(result.result).toBe(null);
      expect(value).toBe('{"a":"something"}');
    });

    it('should assign empty JSON values as strings', () => {
      const environment = new Environment();
      const script = getAssignScript(
        {
          x: { type: CapiVariableTypes.STRING, key: 'x', path: 'stage.x', value: '{}' },
        },
        environment,
      );
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
      const variable7 = {
        type: CapiVariableTypes.NUMBER,
        key: 'x',
        value: 'Math.max(1, 7)',
      };
      const variable8 = {
        type: CapiVariableTypes.STRING,
        key: 'x',
        value: 'he began (as he always did) to fidget',
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
      script = getExpressionStringForValue(variable7);
      expect(script).toBe('Math.max(1, 7)');
      script = getExpressionStringForValue(variable8);
      expect(script).toBe('"he began (as he always did) to fidget"');
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

    // Added Test case for the fix related to PMP-2785
    it('should replace newline in a string with an empty space', () => {
      const variable = {
        type: CapiVariableTypes.STRING,
        key: 'x',
        value: 'Test\nString\n1',
      };

      const script = getExpressionStringForValue(variable);
      expect(script).toBe('"Test String 1"');
    });

    it('should deal with JSON values', () => {
      const jsonVal = '{"content":{"ops":[1, 2, 3]}}';
      const escapedVal = '{\\"content\\":{\\"ops\\":[1,2,3]}}';
      const variable = {
        type: 2,
        value: jsonVal,
      };
      const script = getExpressionStringForValue(variable);
      expect(script).toBe(`"${escapedVal}"`);
    });

    it('should be able to evaluate values nested within JSON', () => {
      const env = new Environment();
      evalScript(`let {app.spr-app-adaptivity.ASUELA.Q3.L4.Name} = "Herman";`, env);
      const jsonVal = `{"content":{"ops":[{"insert":"Dear {app.spr-app-adaptivity.ASUELA.Q3.L4.Name}"}]},"dropdowns":{},"textInputs":{}}`;
      const resultVal = `{\\"content\\":{\\"ops\\":[{\\"insert\\":\\"Dear Herman\\"}]},\\"dropdowns\\":{},\\"textInputs\\":{}}`;
      const variable = {
        type: 2,
        value: jsonVal,
      };
      const script = getExpressionStringForValue(variable, env);
      expect(script).toBe(`"${resultVal}"`);
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

  describe('checkExpressionsWithWrongBrackets', () => {
    it('should update all the invalid curly brackets with round brackets', () => {
      let exppression =
        '{round{{6.23*{q:1468628289324:408|stage.weight.value}}+{12.7*{q:1468628289324:408|stage.height.value}}-{6.8*{q:1468628289324:408|stage.age.value}}+66}}';
      let script = checkExpressionsWithWrongBrackets(exppression);
      expect(script).toBe(
        '{round((6.23*{q:1468628289324:408|stage.weight.value})+(12.7*{q:1468628289324:408|stage.height.value})-(6.8*{q:1468628289324:408|stage.age.value})+66)}',
      );

      exppression = '{round{{stage.a.value}*{{stage.b.value}*{stage.c.value}}}}';
      script = checkExpressionsWithWrongBrackets(exppression);
      expect(script).toBe('{round({stage.a.value}*({stage.b.value}*{stage.c.value}))}');

      exppression =
        '{q:1468628289959:468|stage.exercise.value}+{q:1468628289415:435|stage.BMR.value}+{q:1468628289959:468|stage.TEF.value}';
      script = checkExpressionsWithWrongBrackets(exppression);
      expect(script).toBe(
        '{q:1468628289959:468|stage.exercise.value}+{q:1468628289415:435|stage.BMR.value}+{q:1468628289959:468|stage.TEF.value}',
      );

      exppression = '{session.tutorialScore}';
      script = checkExpressionsWithWrongBrackets(exppression);
      expect(script).toBe('{session.tutorialScore}');

      exppression = '{round({{session.tutorialScore}/30}*100)}%';
      script = checkExpressionsWithWrongBrackets(exppression);
      expect(script).toBe('{round(({session.tutorialScore}/30)*100)}%');

      exppression =
        '{"cards":[{"front":{"text":"a) I just can’t understand why anyone would think that about this issue. Can you explain your reasoning?"},"back":{"text":"b) I see that you feel strongly about this issue, as do I.  I find it difficult to understand the other side here. Can you give me another example to help me gain more insight on this?"}}]}';
      script = checkExpressionsWithWrongBrackets(exppression);
      expect(script).toBe(
        '{"cards":[{"front":{"text":"a) I just can’t understand why anyone would think that about this issue. Can you explain your reasoning?"},"back":{"text":"b) I see that you feel strongly about this issue, as do I.  I find it difficult to understand the other side here. Can you give me another example to help me gain more insight on this?"}}]}',
      );

      exppression = 'You Score is {round({{session.tutorialScore}/30}*100)}%';
      script = checkExpressionsWithWrongBrackets(exppression);
      expect(script).toBe('You Score is {round(({session.tutorialScore}/30)*100)}%');

      exppression =
        '{"metadata":{"rowCount":3,"colCount":2,"properties":{"type":{"default":"Not Editable","values":{}},"format":{"default":"TextFormatDefault","values":{}},"textAlign":{"default":"Left","values":{}},"fontSize":{"default":"16","values":{}},"bold":{"default":"true","values":{"false":{"0":[0],"1":[0],"2":[0]}}},"italic":{"default":"false","values":{}},"strikethrough":{"default":"false","values":{}},"textColor":{"default":"black","values":{}},"backgroundColor":{"default":"#E6e6e6","values":{}},"borderColorTop":{"default":"#ccc","values":{}},"borderColorRight":{"default":"#ccc","values":{}},"borderColorBottom":{"default":"#ccc","values":{}},"borderColorLeft":{"default":"#ccc","values":{}}}},"table":{"mergedCells":[],"rowHeaderWidth":50,"answers":[]}}';
      script = checkExpressionsWithWrongBrackets(exppression);
      expect(script).toBe(
        '{"metadata":{"rowCount":3,"colCount":2,"properties":{"type":{"default":"Not Editable","values":{}},"format":{"default":"TextFormatDefault","values":{}},"textAlign":{"default":"Left","values":{}},"fontSize":{"default":"16","values":{}},"bold":{"default":"true","values":{"false":{"0":[0],"1":[0],"2":[0]}}},"italic":{"default":"false","values":{}},"strikethrough":{"default":"false","values":{}},"textColor":{"default":"black","values":{}},"backgroundColor":{"default":"#E6e6e6","values":{}},"borderColorTop":{"default":"#ccc","values":{}},"borderColorRight":{"default":"#ccc","values":{}},"borderColorBottom":{"default":"#ccc","values":{}},"borderColorLeft":{"default":"#ccc","values":{}}}},"table":{"mergedCells":[],"rowHeaderWidth":50,"answers":[]}}',
      );

      exppression =
        '[["Total Points Possible:","30"],["Your Score:","{session.tutorialScore}"],["Your Percentage:","{round({{session.tutorialScore}/30}*100)}%"]]';
      script = checkExpressionsWithWrongBrackets(exppression);
      expect(script).toBe(
        '[["Total Points Possible:","30"],["Your Score:","{session.tutorialScore}"],["Your Percentage:","{round(({session.tutorialScore}/30)*100)}%"]]',
      );

      exppression =
        '{round({{q:1468628289415:435|stage.BMR.value}*{q:1468628289656:443|stage.activityFactor.value}})}';
      script = checkExpressionsWithWrongBrackets(exppression);
      expect(script).toBe(
        '{round(({q:1468628289415:435|stage.BMR.value}*{q:1468628289656:443|stage.activityFactor.value}))}',
      );

      exppression =
        '{{q:1468628289415:435|stage.BMR.value}+{{q:1468628289415:435|stage.BMR.value}*{q:1468628289656:443|stage.activityFactor.value}}}*0.10';
      script = checkExpressionsWithWrongBrackets(exppression);
      expect(script).toBe(
        '{{q:1468628289415:435|stage.BMR.value}+({q:1468628289415:435|stage.BMR.value}*{q:1468628289656:443|stage.activityFactor.value})}*0.10',
      );
    });
  });

  describe('extractUniqueVariablesFromText', () => {
    it('should handle nested expressions', () => {
      const text =
        '(max({q:1499727122739:724|stage.massofbasket1first.Current Display Value},{q:1523384627938:342|stage.massofbasket1second.Current Display Value},{q:1499727122898:728|stage.Basket1third.Current Display Value},{q:1519241677429:566|stage.Basket1fourth.Current Display Value}))-(min({q:1499727122739:724|stage.massofbasket1first.Current Display Value},{q:1523384627938:342|stage.massofbasket1second.Current Display Value},{q:1499727122898:728|stage.Basket1third.Current Display Value},{q:1519241677429:566|stage.Basket1fourth.Current Display Value})),1';
      const expressions = extractUniqueVariablesFromText(text);
      expect(expressions).toEqual([
        'q:1499727122739:724|stage.massofbasket1first.Current Display Value',
        'q:1523384627938:342|stage.massofbasket1second.Current Display Value',
        'q:1499727122898:728|stage.Basket1third.Current Display Value',
        'q:1519241677429:566|stage.Basket1fourth.Current Display Value',
      ]);
    });
  });
});
