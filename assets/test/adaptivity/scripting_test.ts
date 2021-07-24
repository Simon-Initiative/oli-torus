import { CapiVariableTypes } from 'adaptivity/capi';
import {
  applyState,
  ApplyStateOperation,
  evalScript,
  getAssignScript,
  getValue,
} from 'adaptivity/scripting';
import { Environment } from 'janus-script';

describe('Scripting Interface', () => {
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

    it('should return an assignment script from a capi-like variable', () => {
      const environment = new Environment();
      const script = getAssignScript({ x: { key: 'x', path: 'stage.x', value: 42 } });
      const result = evalScript(script, environment);
      const value = getValue('stage.x', environment);
      expect(script).toBe('let {stage.x} = 42;');
      expect(result.result).toBe(null);
      expect(value).toBe(42);
    });
  });
});
