var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { handleValueExpression } from '../../src/apps/delivery/layouts/deck/DeckLayoutFooter';
import { activities } from './value_expression_convertor_mocks';
describe('Evaluate value expression convertor', () => {
    expect(handleValueExpression(activities, '{stage.earthAge1.value}*100')).toEqual('{e:1616780984451|stage.earthAge1.value}*100');
    it('should not append any activity id as I have passed wrong part Id', () => __awaiter(void 0, void 0, void 0, function* () {
        expect(handleValueExpression(activities, '{stage.earthAge5.value}*100')).toEqual('{stage.earthAge5.value}*100');
    }));
    expect(handleValueExpression(activities, '{stage.MoonAge2.value}*100*{stage.earthAge1.value}')).toEqual('{e:16167809845778|stage.MoonAge2.value}*100*{e:1616780984451|stage.earthAge1.value}');
    expect(handleValueExpression(activities, '{app.spr.adaptivity.something}+1')).toEqual('{app.spr.adaptivity.something}+1');
});
//# sourceMappingURL=value_expression_convertor_test.js.map