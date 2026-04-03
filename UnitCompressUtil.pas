unit UnitCompressUtil;

interface

uses Classes, SysUtils, System.Zip, System.ZLib;

function ZCompressString(aText: string; aCompressionLevel: TZCompressionLevel=zcFastest): string;
function ZDecompressString(aText: string): string;
// ── RLE 기반 (반복 문자가 많을 때 효과적) ─────────────────────────────
function RLECompress(const AInput: string): string;
function RLEDecompress(const AInput: string): string;

implementation

function ZCompressString(aText: string; aCompressionLevel: TZCompressionLevel): string;
var
  strInput,
  strOutput: TStringStream;
  Zipper: TZCompressionStream;
begin
  Result := '';
  strInput := TStringStream.Create(aText);
  strOutput := TStringStream.Create;
  try
    Zipper := TZCompressionStream.Create(strOutput, aCompressionLevel, 15);
    try
      Zipper.CopyFrom(strInput, strInput.Size);
    finally
      Zipper.Free;
    end;

    Result := strOutput.DataString;
  finally
    strInput.Free;
    strOutput.Free;
  end;
end;

function ZDecompressString(aText: string): string;
var
  strInput,
  strOutput: TStringStream;
  UnZipper: TZDeCompressionStream;
begin
  Result := '';
  strInput := TStringStream.Create(aText);
  strOutput := TStringStream.Create;
  try
    strInput.Position := 0;

    UnZipper := TZDeCompressionStream.Create(strInput, 15);
    try
      strOutput.CopyFrom(UnZipper, UnZipper.Size);
    finally
      UnZipper.Free;
    end;

    Result := strOutput.DataString;
  finally
    strInput.Free;
    strOutput.Free;
  end;
end;

function RLECompress(const AInput: string): string;
var
  i, Count : Integer;
  CurChar  : Char;
  SB       : TStringBuilder;
begin
  if AInput = '' then Exit('');

  SB      := TStringBuilder.Create;
  CurChar := AInput[1];
  Count   := 1;
  try
    for i := 2 to Length(AInput) do
    begin
      if AInput[i] = CurChar then
        Inc(Count)
      else
      begin
        SB.Append(Count).Append(CurChar);
        CurChar := AInput[i];
        Count   := 1;
      end;
    end;
    SB.Append(Count).Append(CurChar); // 마지막 그룹
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function RLEDecompress(const AInput: string): string;
var
  i     : Integer;
  Count : Integer;
  SB    : TStringBuilder;
begin
  if AInput = '' then Exit('');

  SB := TStringBuilder.Create;
  i  := 1;
  try
    while i <= Length(AInput) do
    begin
      // 숫자 파싱 (두 자리 이상도 처리)
      Count := 0;
      while (i <= Length(AInput)) and CharInSet(AInput[i], ['0'..'9']) do
      begin
        Count := Count * 10 + Ord(AInput[i]) - Ord('0');
        Inc(i);
      end;

      if i <= Length(AInput) then
      begin
        SB.Append(AInput[i], Count);
        Inc(i);
      end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

end.
