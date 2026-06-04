import { gleamParse } from '../gleam/torusExpression';

export const MathPrototype = {
  mounted() {
    const expressionInput = this.el.querySelector('#math-expression') as HTMLInputElement | null;
    const parseButton = this.el.querySelector('#parse-client') as HTMLButtonElement | null;

    parseButton?.addEventListener('click', () => {
      try {
        const expression = expressionInput?.value || '';
        this.pushEvent('client_parse_result', gleamParse(expression));
      } catch (error) {
        this.pushEvent('client_parse_result', {
          status: 'exception',
          value: error instanceof Error ? error.message : String(error),
          inspect: String(error),
        });
      }
    });
  },
};
