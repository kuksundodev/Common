/// <summary>
///   시간순 정렬 가능한 UUID 생성기 (UUIDv7, RFC 9562). 48비트 Unix ms 타임스탬프 선행 →
///     생성 순서대로 정렬. 동일 ms 내 12비트 단조 카운터로 엄격 순서 보장. 스레드안전.
/// </summary>
unit UnitSCUuid;

interface

{$REGION 'uses'}
uses
  System.SysUtils,
  Winapi.Windows;
{$ENDREGION}

type
  /// <summary>
  ///   UUIDv7 생성기(클래스 메서드 전용).
  /// </summary>
  TSCUuid = class
  strict private
    class var FCounter: Cardinal;
    class var FLastMs: UInt64;
    class var FLock: TRTLCriticalSection;

    class constructor Create;
    class destructor Destroy;

    class function CurrentUnixMs: UInt64; static;
  public
    /// <summary>
    ///   새 UUIDv7 (TGUID). 시간순 정렬·단조.
    /// </summary>
    class function NewV7: TGUID; static;
    /// <summary>
    ///   새 UUIDv7 표준 문자열(소문자, 중괄호 없음).
    /// </summary>
    class function NewV7String: string; static;
  end;

implementation

{$REGION 'CNG (bcrypt.dll) 바인딩'}
const
  bcrypt = 'bcrypt.dll';
  BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;

function BCryptGenRandom(hAlgorithm: THandle; pbBuffer: PByte; cbBuffer, dwFlags: ULONG): Integer; stdcall; external bcrypt;

// CSPRNG 으로 ALen 바이트의 보안 난수를 LBuf 에 채운다. 실패 시 예외.
procedure SecureRandomBytes(var ABuf: array of Byte; ALen: Integer);
begin
  if ALen <= 0 then
  begin
    Exit;
  end;

  if BCryptGenRandom(0, @ABuf[0], ALen, BCRYPT_USE_SYSTEM_PREFERRED_RNG) <> 0 then
  begin
    raise Exception.Create('UUID 보안 난수 생성 실패(BCryptGenRandom)');
  end;
end;
{$ENDREGION}

{$REGION 'TSCUuid'}

class constructor TSCUuid.Create;
begin
  InitializeCriticalSection(FLock);
  FLastMs := 0;
  FCounter := 0;
end;

class destructor TSCUuid.Destroy;
begin
  DeleteCriticalSection(FLock);
end;

class function TSCUuid.CurrentUnixMs: UInt64;
var
  LFt: TFileTime;
  LLi: UInt64;
begin
  GetSystemTimeAsFileTime(LFt);   // 100ns 단위, 1601-01-01 UTC 기준
  LLi := (UInt64(LFt.dwHighDateTime) shl 32) or LFt.dwLowDateTime;
  Result := (LLi - UInt64(116444736000000000)) div 10000;   // → Unix ms(UTC)
end;

class function TSCUuid.NewV7: TGUID;
var
  LMs: UInt64;
  LRandA: Cardinal;
  LB: array[0..15] of Byte;
begin
  EnterCriticalSection(FLock);
  try
    LMs := CurrentUnixMs;
    if LMs <= FLastMs then
    begin
      LMs := FLastMs;
      Inc(FCounter);
      if FCounter > $FFF then   // 12비트 카운터 소진 → 다음 ms 차용(단조 유지)
      begin
        Inc(FLastMs);
        LMs := FLastMs;
        FCounter := 0;
      end;
    end
    else
    begin
      FLastMs := LMs;
      FCounter := 0;
    end;
    LRandA := FCounter and $FFF;

    LB[0] := Byte(LMs shr 40);
    LB[1] := Byte(LMs shr 32);
    LB[2] := Byte(LMs shr 24);
    LB[3] := Byte(LMs shr 16);
    LB[4] := Byte(LMs shr 8);
    LB[5] := Byte(LMs);
    // rand_b 영역(LB[8..15], 8바이트)을 CSPRNG 으로 채운 뒤 variant 비트만 덮어쓴다
    var LRand: array[0..7] of Byte;
    SecureRandomBytes(LRand, Length(LRand));

    LB[6] := $70 or Byte((LRandA shr 8) and $0F);   // version 7 + rand_a 상위
    LB[7] := Byte(LRandA);                          // rand_a 하위
    LB[8] := $80 or (LRand[0] and $3F);             // variant 10 + rand_b 상위 6비트
    for var I := 9 to 15 do
      LB[I] := LRand[I - 8];                        // rand_b 나머지(CSPRNG)
  finally
    LeaveCriticalSection(FLock);
  end;

  Result.D1 := (UInt32(LB[0]) shl 24) or (UInt32(LB[1]) shl 16) or (UInt32(LB[2]) shl 8) or LB[3];
  Result.D2 := (UInt16(LB[4]) shl 8) or LB[5];
  Result.D3 := (UInt16(LB[6]) shl 8) or LB[7];
  for var I := 0 to 7 do
    Result.D4[I] := LB[8 + I];
end;

class function TSCUuid.NewV7String: string;
begin
  Result := LowerCase(Copy(GUIDToString(NewV7), 2, 36));   // {..} 제거 + 소문자
end;

{$ENDREGION}

end.
[출처] UUID v7 (한국 델파이 동호회 - 델마당) | 작성자 시골프로그래머
