unit UnitBase62Util;

interface

type
  TBase62Util = class
    class function EncodeBase62(Value: UInt64): string;
    class function DecodeBase62(const S: string): UInt64;
  end;

const
  BASE62_CHARS: string = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

implementation

{ TBase62Util }

class function TBase62Util.DecodeBase62(const S: string): UInt64;
var
  I: Integer;
  PosValue: Integer;
begin
  Result := 0;

  for I := 1 to Length(S) do
  begin
    PosValue := Pos(S[I], BASE62_CHARS) - 1;
    Result := Result * 62 + PosValue;
  end;
end;

class function TBase62Util.EncodeBase62(Value: UInt64): string;
var
  Remainder: UInt64;
begin
  Result := '';

  repeat
    Remainder := Value mod 62;
    Result := BASE62_CHARS[Remainder + 1] + Result;
    Value := Value div 62;
  until Value = 0;
end;

end.
