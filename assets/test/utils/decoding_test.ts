import { b64DecodeUnicode } from 'utils/decode';

it('decodes special characters correctly', () => {
  const encoded =
    'eyJhY3Rpdml0aWVzIjpudWxsLCJhbGxPYmplY3RpdmVzIjpudWxsLCJhdXRob3JFbWFpbCI6bnVsbCwiY29udGVudCI6InTDoSIsImVkaXRvck1hcCI6bnVsbCwiZ3JhZGVkIjpudWxsLCJvYmplY3RpdmVzIjpudWxsLCJwcm9qZWN0U2x1ZyI6bnVsbCwicmVzb3VyY2VTbHVnIjpudWxsLCJ0aXRsZSI6bnVsbH0=';

  const result = JSON.parse(b64DecodeUnicode(encoded));
  expect((result as any).content).toEqual('tá');
});
