unit UnitMormot_JwtUtil;

interface

uses
  mormot.core.base, mormot.core.buffers, mormot.core.variants,
  mormot.crypt.secure, mormot.crypt.jwt, mormot.crypt.openssl;

function VerifyToken(const APublicKey: RawByteString; const AToken: RawUTF8): boolean;

implementation

function VerifyToken(const APublicKey: RawByteString; const AToken: RawUTF8): boolean;
var
  LToken: TJWTAbstract;
  jwt: TJWTContent;
begin
  LToken := TJwtCrypt.Create(caaRS256, APublicKey, [jrcIssuer], []);
  try
    LToken.Options := [joHeaderParse, joAllowUnexpectedClaims];
    LToken.Verify(AToken, jwt);
    Result := jwt.result = jwtValid;
  finally
    LToken.Free;
  end;
end;

//function VerifyJWT(const aJWT: RawByteString; const aPublicKey: RawByteString; out JWT: Variant): Boolean;
//  function VerifyWithmORMot(const aJWT: RawByteString; out JWT: Variant): Boolean;
//  var
//    Header, Payload, Signature: RawByteString;
//    sigBinary, msgBinary: TBytes;
//    idx, step: Integer;
//    aBuf: PAnsiChar;
//  begin
//    Header:= '';
//    Payload:= '';
//    Signature:= '';
//    idx:= 0;
//    step:= 0;
//    aBuf:= PAnsiChar(aJWT);
//    while aBuf[idx] <> '' do begin
//       INC(idx);
//       if aBuf[idx] = '.' then begin
//         INC(step);
//         if step=1 then
//           SetString(Header, aBuf, idx)
//         else
//         if step=2 then
//           SetString(Payload, aBuf, idx)
//         else
//           SetString(Signature, aBuf, idx);
//         INC(aBuf, idx+1);
//         idx:= 0;
//
//       end;
//    end;
//
//    if (idx > 0) and (step < 3) then
//      SetString(Signature, aBuf, idx);
//
//    JWT:= _Obj([]);
//    sigBinary:= Base64UrlDecode(Signature);
//    RawByteStringToBytes(Header+'.'+Payload, msgBinary);
//
//    Result:= OpenSslVerify('', '', Pointer(msgBinary), Pointer(aPublicKey), Pointer(sigBinary), Length(msgBinary), Length(aPublicKey), Length(sigBinary));
//    if Result then
//      JWT:= Js2Var(Base64uriToBin(PAnsiChar(Payload), Length(Payload)));
//  end;
//
//begin
//  Result:= VerifyWithmORMot(aJWT, JWT);
//end;

end.
