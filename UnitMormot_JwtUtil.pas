unit UnitMormot_JwtUtil;

interface

uses System.SysUtils,
  mormot.core.base, mormot.core.buffers, mormot.core.variants,
  mormot.core.unicode,
  mormot.crypt.core, mormot.crypt.secure, mormot.crypt.jwt, mormot.crypt.openssl;

type
  TJwtUtil = class
    type
      TMsgFlag = set of (mfCompressed, mfEncrypted, mfSigned);
      TMsgHeader = record
        Version: Integer;
        Flag: TMsgFlag;
      end;

    class function BuildHeader(const AVersion: Integer; AFlags: TMsgFlag): string;
    class function ParseHeader(const S: string; out Header: TMsgHeader; out Payload: string): Boolean;
    class function VerifyToken(const APublicKey: RawByteString; const AToken: RawUTF8): boolean;

    class function EncodeMsgSecure(const AMsg: string; const AKey: RawUtf8;
                    AVersion: Integer = 2; AFlags: TMsgFlag = [mfCompressed, mfEncrypted, mfSigned]): string;
    class function DecodeMsgSecure(const S: string; const AKey: RawUtf8): string;
    class function EncodeString(const AMsg: String; const AFlags: TMsgFlag): boolean;
    class function AesEncrypt(const Data, Key: RawByteString): RawByteString;
    class function AesDecrypt(const Data, Key: RawByteString): RawByteString;
  end;

implementation

class function TJwtUtil.AesDecrypt(const Data,
  Key: RawByteString): RawByteString;
var
  aes: TAesCfb;
  iv: TAesBlock;
  cipher: RawByteString;
begin
//  FillChar(iv, SizeOf(iv), 0); // Encrypt와 동일해야 함
  TAesPrng.Main.FillRandom(@IV, SizeOf(IV));

  aes := TAesCfb.Create(Key, 256, @iv);
  try
    Move(Data[1], IV, SizeOf(IV));
    cipher := Copy(Data, SizeOf(IV)+1, MaxInt);
    aes.Decrypt(pointer(cipher), pointer(Result), 256);
  finally
    aes.Free;
  end;
end;

class function TJwtUtil.AesEncrypt(const Data,
  Key: RawByteString): RawByteString;
var
  aes: TAesCfb;
  iv: TAesBlock; // 16 bytes
begin
//  FillChar(iv, SizeOf(iv), 0); //실제로는 랜덤 권장
  TAesPrng.Main.FillRandom(@IV, SizeOf(IV));

  aes := TAesCfb.Create(Key, 256, @iv);
  try
    Result := IV + aes.Encrypt(Data);
  finally
    aes.Free;
  end;
end;

class function TJwtUtil.BuildHeader(const AVersion: Integer;
  AFlags: TMsgFlag): string;
var
  flags: string;
begin
  flags := '';

  if mfCompressed in AFlags then flags := flags + 'C';
  if mfEncrypted  in AFlags then flags := flags + 'E';
  if mfSigned     in AFlags then flags := flags + 'S';

  if flags = '' then
    flags := 'N';

  Result := Format('MSG%d%s:', [AVersion, flags]);
end;

class function TJwtUtil.DecodeMsgSecure(const S: string;
  const AKey: RawUtf8): string;
var
  header: TMsgHeader;
  payload, dataPart, macPart: string;
  bin: RawByteString;
  utf8: RawUtf8;
  calcMac: RawByteString;
  LSha256Digest: TSha256Digest;
  p: Integer;
begin
  if not ParseHeader(S, header, payload) then
    Exit(S);

  // payload 분리 (data.mac)
  p := Pos('.', payload);
  if p > 0 then
  begin
    dataPart := Copy(payload, 1, p - 1);
    macPart  := Copy(payload, p + 1, MaxInt);
  end
  else
    dataPart := payload;

  bin := Base64ToBin(dataPart);

  // 1. HMAC 검증
  if mfSigned in header.Flag then
  begin
    HmacSha256(AKey, bin, LSha256Digest);
    calcMac := Sha256DigestToString(LSha256Digest);

    if BinToBase64(calcMac) <> macPart then
      raise Exception.Create('HMAC verification failed');
  end;

  // 2. 복호화
  if mfEncrypted in header.Flag then
    bin := AesDecrypt(bin, AKey);
  // 3. 압축 해제
  if mfCompressed in header.Flag then
    utf8 := AlgoSynLZ.Decompress(bin)
  else
    utf8 := bin;

  Result := Utf8ToString(utf8);
end;

class function TJwtUtil.EncodeMsgSecure(const AMsg: string; const AKey: RawUtf8;
  AVersion: Integer; AFlags: TMsgFlag): string;
var
  data: RawByteString;
  utf8: RawUtf8;
  header, payload, mac: string;
begin
  utf8 := StringToUtf8(AMsg);
  data := utf8;

  // 1. 압축
  if mfCompressed in AFlags then
    data := AlgoSynLZ.Compress(data);

  // 2. 암호화 (AES-256-CFB)
  if mfEncrypted in AFlags then
    data := AesEncrypt(data, AKey);
//    data := TAesCfb.Encrypt(data, AKey);

  payload := BinToBase64(data);

  // 3. HMAC (SHA-256)
  if mfSigned in AFlags then
  begin
    mac := BinToBase64(HmacSha256(AKey, data));
    payload := payload + '.' + mac;
  end;

  header := BuildHeader(AVersion, AFlags);
  Result := header + payload;
end;

class function TJwtUtil.EncodeString(const AMsg: String;
  const AFlags: TMsgFlag): boolean;
begin
  TJwtUtil.EncodeMsgSecure(AMsg,
end;

class function TJwtUtil.ParseHeader(const S: string; out Header: TMsgHeader;
  out Payload: string): Boolean;
var
  p, version: Integer;
  flagChar: Char;
begin
  Result := False;

  if not S.StartsWith('MSG') then
    Exit;

  p := Pos(':', S);
  if p = 0 then
    Exit;

  // MSG1C
  if p < 5 then
    Exit;

  version := StrToIntDef(Copy(S, 4, 1), -1);
  if version < 0 then
    Exit;

  flagChar := S[5];

  Header.Version := version;

  case flagChar of
    'C': Header.Flag := mfCompressed;
    'N': Header.Flag := mfNone;
  else
    Exit;
  end;

  Payload := Copy(S, p + 1, MaxInt);
  Result := True;
end;

class function TJwtUtil.VerifyToken(const APublicKey: RawByteString; const AToken: RawUTF8): boolean;
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
