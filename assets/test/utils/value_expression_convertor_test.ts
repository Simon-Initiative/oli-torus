import { handleValueExpression } from '../../src/apps/delivery/layouts/deck/DeckLayoutFooter';
import { activities } from './value_expression_convertor_mocks';

describe('Evaluate value expression convertor', () => {
  expect(handleValueExpression(activities, '{stage.earthAge1.value}*100')).toEqual(
    '{e:1616780984451|stage.earthAge1.value}*100',
  );
  it('should not append any activity id as I have passed wrong part Id', async () => {
    expect(handleValueExpression(activities, '{stage.earthAge5.value}*100')).toEqual(
      '{stage.earthAge5.value}*100',
    );
  });

  expect(
    handleValueExpression(activities, '{stage.MoonAge2.value}*100*{stage.earthAge1.value}'),
  ).toEqual('{e:16167809845778|stage.MoonAge2.value}*100*{e:1616780984451|stage.earthAge1.value}');
});
