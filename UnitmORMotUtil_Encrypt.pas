unit UnitmORMotUtil_Encrypt;

interface

uses
  // mORMot V2 Cryptographic Framework
  mormot.crypt.core,    // Core cryptographic functions and types
  mormot.crypt.secure,  // Secure random number generation and key derivation
  mormot.core.base,     // Base utility functions and types
  mormot.core.text,     // Text processing and encoding functions
  mormot.core.unicode,
  mormot.core.buffers;  // Buffer management and manipulation

//====================================================================================
// ENUMERATION TYPES
//====================================================================================

/// <summary>
/// Defines the available AES encryption modes supported by this application
/// </summary>
/// <remarks>
/// ECB: Electronic Codebook - Simplest but least secure (deterministic)
/// CBC: Cipher Block Chaining - Most common, requires padding
/// CFB: Cipher Feedback - Stream cipher mode, no padding needed
/// OFB: Output Feedback - Stream cipher mode, no padding needed
/// CTR: Counter Mode - Fast, parallelizable stream cipher
/// GCM: Galois/Counter Mode - AEAD mode with built-in authentication
/// CFC: mORMot CFB + CRC32C - Custom AEAD with integrity verification
/// OFC: mORMot OFB + CRC32C - Custom AEAD with integrity verification
/// CTC: mORMot CTR + CRC32C - Custom AEAD with integrity verification
/// </remarks>
type
  TEncryptionMode = (
    emAES_ECB,      // Electronic Codebook (NOT RECOMMENDED for production)
    emAES_CBC,      // Cipher Block Chaining
    emAES_CFB,      // Cipher Feedback
    emAES_OFB,      // Output Feedback
    emAES_CTR,      // Counter Mode
    emAES_GCM,      // Galois/Counter Mode (AEAD)
    emAES_CFC,      // CFB + CRC32C (mORMot custom AEAD)
    emAES_OFC,      // OFB + CRC32C (mORMot custom AEAD)
    emAES_CTC       // CTR + CRC32C (mORMot custom AEAD)
  );

/// <summary>
/// Defines the supported AES key sizes in bits
/// </summary>
/// <remarks>
/// Larger key sizes provide stronger security but slightly impact performance
/// 256-bit keys are recommended for high-security applications
/// </remarks>
  TKeySize = (
    ks128,          // 128-bit key (16 bytes) - Fast, good security
    ks192,          // 192-bit key (24 bytes) - Enhanced security
    ks256           // 256-bit key (32 bytes) - Maximum security
  );

  TEncryptParam = packed record
    EncryptionMode: TEncryptionMode;
    KeySize: TKeySize;
    IsIVRandom,
    IsCompressed: Boolean;
  end;

  TMormotCryptUtil = class
    class function IntToBase62WithLength(Value: UInt64; const MinLength: Integer = 0): string;
    class function Base62ToInt(const S: string): UInt64;
    class function EncodeParam2Base62(AParamRec: TEncryptParam): string;
    class function DecodeParamFromBase62(const ABase62: string): TEncryptParam;
    //ABase64 길이를 기반으로 특정 위치의 5문자 반환
    class function Extract5FromMsg(const AMsg: string; ASeed: Integer=0): string;
    class function MakePasswdFromMsg(const AMsg: string): string;
    class function GetKeySizeInBits(const AKeySize: TKeySize): Integer;
    class function CreateAESInstance(const APwd: string; const AMode: TEncryptionMode; const AKeySize: TKeySize; ASalt: RawByteString=''): TAesAbstract;
    class function GetEncryptModeDesc(const AMode: TEncryptionMode): string;

    class function EncryptMsgByMode(const AMsg: string; const AMode: TEncryptionMode;
      const AKeySize: TKeySize; const AIsIVRandom: Boolean=true;
      APwd: string=''; ASalt: RawByteString=''): string;
    class function DecryptMsgByMode(const AMsgEncrypted: string; APwd: string='';
      AMode: TEncryptionMode=emAES_CFB; AKeySize: TKeySize=ks256): string;
  end;

const
  // Seed 기반 고정 셔플 순서 (0-based index, 10자리)
  SHUFFLE_MAP: array[0..9] of Integer = (3, 7, 1, 9, 0, 5, 2, 8, 4, 6);

implementation

uses UnitCompressUtil;

// 문자열 Shuffle 함수
function ShuffleString(const AInput: string): string;
var
  i: Integer;
begin
  Result := '';

  if Length(AInput) <> 10 then
    exit;
//    raise Exception.Create('입력 문자열은 반드시 10자리여야 합니다.');

  SetLength(Result, 10);

  for i := 0 to 9 do
    Result[i + 1] := AInput[SHUFFLE_MAP[i] + 1];  // 1-based index
end;


// 문자열 복구 함수 (Unshuffle)
function UnshuffleString(const AInput: string): string;
var
  i: Integer;
begin
  Result := '';

  if Length(AInput) <> 10 then
    exit;
//    raise Exception.Create('입력 문자열은 반드시 10자리여야 합니다.');

  SetLength(Result, 10);

  for i := 0 to 9 do
    Result[SHUFFLE_MAP[i] + 1] := AInput[i + 1];  // 역방향 매핑
end;

{ TMormotCryptUtil }

class function TMormotCryptUtil.Base62ToInt(const S: string): UInt64;
const
  BASE62 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
var
  i, posVal: Integer;
begin
  Result := 0;

  for i := 1 to Length(S) do
  begin
    posVal := Pos(S[i], BASE62) - 1;

    if posVal < 0 then
      exit;
//      raise Exception.Create('Invalid Base62 character');

    Result := Result * 62 + UInt64(posVal);
  end;
end;

class function TMormotCryptUtil.CreateAESInstance(const APwd: string; const AMode: TEncryptionMode;
  const AKeySize: TKeySize; ASalt: RawByteString): TAesAbstract;
var
  Key: THash256;               // Derived encryption key (256-bit)
  KeyBits: Integer;            // Selected key size in bits
//  Salt: RawByteString;         // Salt for key derivation
begin
  Result := nil;
  KeyBits := GetKeySizeInBits(AKeySize);

  // Use a fixed salt for demonstration purposes
  // SECURITY NOTE: In production applications, use a unique random salt
  // for each password/encryption operation and store it alongside the ciphertext
  if ASalt = '' then
    ASalt := 'mormot_demo_fixed_salt_2024';

  // Derive encryption key using PBKDF2-HMAC-SHA256
  // This strengthens the user's password against brute-force attacks
  // The iteration count (1000) is minimal - consider 10,000+ for production
  Pbkdf2HmacSha256(ToUtf8(APwd), ASalt, 1000, Key);

  // Create the appropriate AES implementation based on selected mode
  case AMode of
    emAES_ECB: Result := TAesEcb.Create(Key, KeyBits); // NOT RECOMMENDED for production
    emAES_CBC: Result := TAesCbc.Create(Key, KeyBits); // Standard mode, requires padding
    emAES_CFB: Result := TAesCfb.Create(Key, KeyBits); // Stream mode, no padding
    emAES_OFB: Result := TAesOfb.Create(Key, KeyBits); // Stream mode, no padding
    emAES_CTR: Result := TAesCtr.Create(Key, KeyBits); // Fast, parallelizable
    emAES_GCM: Result := TAesGcm.Create(Key, KeyBits); // AEAD mode (authenticated)
    emAES_CFC: Result := TAesCfc.Create(Key, KeyBits); // mORMot AEAD variant
    emAES_OFC: Result := TAesOfc.Create(Key, KeyBits); // mORMot AEAD variant
    emAES_CTC: Result := TAesCtc.Create(Key, KeyBits); // mORMot AEAD variant
  end;

  // Security: Clear sensitive key material from memory immediately after use
  // This prevents key recovery through memory dumps or swap files
  FillChar(Key, SizeOf(Key), 0);
end;

class function TMormotCryptUtil.DecodeParamFromBase62(
  const ABase62: string): TEncryptParam;
var
  value: UInt64;
begin
  Result := Default(TEncryptParam);

  if Length(ABase62) <> 5 then
    exit;
//    raise Exception.Create('Invalid encoded length');

  value := Base62ToInt(ABase62);

  // 2. 비트 분해
  Result.EncryptionMode := TEncryptionMode((value shr 24) and $FF);
  Result.KeySize     := TKeySize((value shr 16) and $FF);
  Result.IsIVRandom  := ((value shr 8) and $FF) <> 0;
  Result.IsCompressed:= (value and $FF) <> 0;
end;

class function TMormotCryptUtil.DecryptMsgByMode(const AMsgEncrypted: string; APwd: string;
  AMode: TEncryptionMode; AKeySize: TKeySize): string;
var
  LAES: TAesAbstract;           // AES decryption instance
  LHeader, LParam, LPwd: string;
  LParamRec: TEncryptParam;
  LPlainText: RawByteString;    // Decrypted output bytes
  LCipherText: RawByteString;   // Encrypted input bytes
begin
  Result := '';

  LCipherText := StringToUtf8(Copy(AMsgEncrypted, 11, Length(AMsgEncrypted)-10));
//  LCipherText := AlgoSynLZ.Decompress(LCipherText);

  LHeader := Copy(AMsgEncrypted, 1, 10);
  LHeader := UnshuffleString(LHeader);

  if LHeader = '' then
    exit;

  LParam := Copy(LHeader, 1, 5);
  LPwd := Copy(LHeader, 6, 5);

  LParamRec := DecodeParamFromBase62(LParam);

  LAES := CreateAESInstance(LPwd, LParamRec.EncryptionMode, LParamRec.KeySize, '');

  if LAES = nil then
  begin
    Exit;
  end;

  try
    LCipherText := Base64ToBin(LCipherText);  // Decode Base64

    if LParamRec.IsCompressed then
      LCipherText := StringToUtf8(ZDecompressString(Utf8ToString(LCipherText)));

    // Perform decryption with PKCS7 padding removal
    // The random IV parameter must match the encryption settings
    LPlainText := LAES.DecryptPkcs7(LCipherText, LParamRec.IsIVRandom);
    Result := Utf8ToString(LPlainText);
  finally
    if Assigned(LAES) then
      LAES.Free;
  end;

end;

class function TMormotCryptUtil.EncodeParam2Base62(AParamRec: TEncryptParam): string;
var
  value: UInt64;
begin
  // 비트 패킹
  value :=
    (UInt64(Ord(AParamRec.EncryptionMode)) shl 24) or
    (UInt64(Ord(AParamRec.KeySize)) shl 16) or
    (UInt64(Ord(AParamRec.IsIVRandom)) shl 8) or
    UInt64(Ord(AParamRec.IsCompressed));

  // Base62 변환 → 5자리
  Result := IntToBase62WithLength(value, 5);
end;

class function TMormotCryptUtil.EncryptMsgByMode(const AMsg: string;
  const AMode: TEncryptionMode; const AKeySize: TKeySize;
  const AIsIVRandom: Boolean; APwd: string; ASalt: RawByteString): string;
var
  LAES: TAesAbstract;
  LPlainText: RawByteString;
  LCipherText: RawByteString;   // Encrypted output bytes
  LHeader: string; //Parameter(5자리) + Pwd(5자리)
  LParamRec: TEncryptParam;
begin
  Result := '';

  if APwd = '' then
    APwd := MakePasswdFromMsg(AMsg);

  LAES := CreateAESInstance(APwd, AMode, AkeySize, ASalt);
  try
    if LAES = nil then
    begin
      Exit;
    end;

    LParamRec.EncryptionMode := AMode;
    LParamRec.KeySize := AKeySize;
    LParamRec.IsIVRandom := AIsIVRandom;
    LParamRec.IsCompressed := Length(AMsg) > 200;

    LHeader := EncodeParam2Base62(LParamRec);

    // Convert input text to UTF-8 byte representation

    if LParamRec.IsCompressed then
      LPlainText := StringToUtf8(ZCompressString(AMsg))
//    LPlainText := AlgoSynLZ.Compress(LPlainText)
    else
      LPlainText := StringToUtf8(AMsg);

    // Perform encryption with PKCS7 padding and optional random IV
    // The CheckBoxUseRandomIV.Checked parameter determines whether to use
    // a cryptographically secure random IV (recommended) or a zero IV
    LCipherText := LAES.EncryptPkcs7(LPlainText, AIsIVRandom);
    Result := ShuffleString(LHeader+APwd) + Utf8ToString(BinToBase64(LCipherText));
  finally
    if Assigned(LAES) then
      LAES.Free;
  end;
end;

class function TMormotCryptUtil.Extract5FromMsg(const AMsg: string;
  ASeed: Integer): string;
var
  Position: Integer;
begin
  Result := '';

  if AMsg = '' then
    Exit;

  if ASeed = 0 then
    ASeed := (Length(AMsg) div 2) - 2;

  // 위치 = (길이 × 0.37) + seed
  Position := Round(Length(AMsg) * 0.37) + ASeed;

  // 범위 검사: 5자리를 추출할 수 있는지 확인
  if (Position < 1) or (Position + 4 > Length(AMsg)) then
    Result := '!@#$%'
  else
    Result := Copy(AMsg, Position, 5);
end;

class function TMormotCryptUtil.GetEncryptModeDesc(
  const AMode: TEncryptionMode): string;
begin
  case AMode of
    emAES_ECB: Result := 'Electronic Codebook - Each block encrypted independently. NOT SECURE for multiple blocks!';
    emAES_CBC: Result := 'Cipher Block Chaining - Each block XORed with previous ciphertext. Requires padding.';
    emAES_CFB: Result := 'Cipher Feedback - Stream cipher mode. No padding required.';
    emAES_OFB: Result := 'Output Feedback - Stream cipher mode. No padding required.';
    emAES_CTR: Result := 'Counter Mode - Fast, parallelizable stream cipher. No padding required.';
    emAES_GCM: Result := 'Galois/Counter Mode - AEAD mode with built-in authentication.';
    emAES_CFC: Result := 'mORMot CFB + CRC32C - Custom AEAD with integrity check.';
    emAES_OFC: Result := 'mORMot OFB + CRC32C - Custom AEAD with integrity check.';
    emAES_CTC: Result := 'mORMot CTR + CRC32C - Custom AEAD with integrity check.';
  else
    Result := 'Unknown mode';
  end;

end;

class function TMormotCryptUtil.GetKeySizeInBits(const AKeySize: TKeySize): Integer;
begin
  case AKeySize of
    ks128: Result := 128;    // Fast encryption, good security
    ks192: Result := 192;    // Enhanced security
    ks256: Result := 256;    // Maximum security (recommended)
  else
    Result := 256;           // Default to maximum security
  end;
end;

class function TMormotCryptUtil.IntToBase62WithLength(Value: UInt64;
  const MinLength: Integer): string;
const
  BASE62: PChar = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
var
  tmp: string;
  rem: UInt64;
begin
  if Value = 0 then
    tmp := '0'
  else
  begin
    tmp := '';
    while Value > 0 do
    begin
      rem := Value mod 62;
      Value := Value div 62;
      tmp := BASE62[rem] + tmp;
    end;
  end;

  // 고정 길이 맞추기 (앞쪽 0 padding)
  while Length(tmp) < MinLength do
    tmp := '0' + tmp;

  Result := tmp;
end;

class function TMormotCryptUtil.MakePasswdFromMsg(const AMsg: string): string;
var
  SHA256Hash2: TSha256Digest;
  Hash: RawByteString;         // Computed hash as hex string
begin
  SHA256Hash2 := Sha256Digest(pointer(AMsg), Length(AMsg));
  Hash := BinToHex(@SHA256Hash2, SizeOf(SHA256Hash2));
  Result := Extract5FromMsg(Hash);
end;

end.
