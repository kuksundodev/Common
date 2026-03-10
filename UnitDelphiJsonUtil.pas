unit UnitDelphiJsonUtil;

interface

uses System.SysUtils, System.Classes, System.JSON;

type
  TJsonUtil = class
    class function GetTJSONArrayFromJsonObjStr(const AJsonObj: string; out AJsonAry: TJSONArray): string;
  end;

implementation

{ TJsonUtil }

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

end.
