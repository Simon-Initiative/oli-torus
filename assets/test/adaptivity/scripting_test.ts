import { CapiVariableTypes } from 'adaptivity/capi';
import { applyState, ApplyStateOperation, evalScript, getValue } from 'adaptivity/scripting';
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
});
