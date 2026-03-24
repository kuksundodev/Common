unit UnitDelphiJsonUtil;

interface

uses System.SysUtils, System.Classes, System.JSON;

type
  TJsonUtil = class
    class function GetTJSONArrayFromJsonObjStr(const AJsonObj: string; out AJsonAry: TJSONArray): string;
    class function GetTJSONArrayFromJsonAryStr(const AJsonAry: string): TJSONArray;
    class function GetTJSONObjectFromJsonObjStr(const AJsonObjStr: string; out AJsonObject: TJSONObject): Boolean;
  end;

implementation

{ TJsonUtil }

class function TJsonUtil.GetTJSONArrayFromJsonAryStr(
  const AJsonAry: string): TJSONArray;
var
  JSONValue: TJSONValue;
begin
  Result := nil;

  JSONValue := TJSONObject.ParseJSONValue(AJsonAry);
  if JSONValue is TJSONArray then
    Result := JSONValue as TJSONArray
  else
    JSONValue.Free;
end;

class function TJsonUtil.GetTJSONArrayFromJsonObjStr(
  const AJsonObj: string; out AJsonAry: TJSONArray): string;
var
  LJSONValue: TJSONValue;
begin
  Result := '';
  try
    LJSONValue := TJSONObject.ParseJSONValue(AJsonObj);

    if Assigned(LJSONValue) and (LJSONValue is TJSONObject) then
      AJsonAry.AddElement(LJSONValue as TJSONObject)
    else
      LJSONValue.Free; // TJSONObject가 아니면 메모리 해제
  except
    on E: Exception do
      Result := Format('JSON 파싱 오류: %s', [E.Message]);
  end;
end;

class function TJsonUtil.GetTJSONObjectFromJsonObjStr(const AJsonObjStr: string;
  out AJsonObject: TJSONObject): Boolean;
var
  LValue: TJSONValue;
begin
  Result := False;
  LValue := TJSONObject.ParseJSONValue(AJsonObjStr);
  if Assigned(LValue) then
  begin
    if LValue is TJSONObject then
    begin
      AJsonObject := LValue as TJSONObject;
      Result := True;
    end
    else
      LValue.Free; // JSON이 Object가 아닌 경우 메모리 해제
  end;
end;

end.
