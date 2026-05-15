unit UnitmORMotUtil_Json;

interface

uses
  System.JSON,            // TJSONArray, TJSONObject, TJSONString
  mormot.core.base,
  mormot.core.data,
  mormot.core.text,
  mormot.core.variants;   // TDocVariantData

type
  TMormot_Json = class
    class function DocVariantToJsonArray(const ADoc: variant): TJSONArray;
    class function DocVariantToJsonArrayViaJson(const ADoc: variant): TJSONArray;
  end;

// var
//   fMembers: variant;
//   member: TMember //= Packed Record
//TDocVariantData(fMembers).AddItem(_ObjFast(RecordSaveJson(member, TypeInfo(TMember))));
//TDocVariantData(fMembers).AddItem(_JsonFast(RecordSaveJson(member, TypeInfo(TMember))));
//TDocVariantData(fMembers).AddItemRtti(@member, Rtti.RegisterType(TypeInfo(TMember)));
implementation

{ TMormot_Json }

class function TMormot_Json.DocVariantToJsonArray(
  const ADoc: variant): TJSONArray;
var
  arrData : TDocVariantData;// absolute ADoc;  // 복사 없이 직접 참조
  rowVar  : variant;
  rowData : TDocVariantData;
  jArr    : TJSONArray;
  jObj    : TJSONObject;
  i       : Integer;
  name    : string;
  val     : string;
  LJson: RawUtf8;
begin
  jArr := TJSONArray.Create;
  try
    // ADoc이DocVariant 타입인지 확인
    if not DocVariantType.IsOfType(ADoc) then
//    if not (dvoIsArray in TDocVariantData(arrData).Options) then
    begin
      Result := jArr;
      Exit;
    end;

    // DocVariantData로 캐스팅
    arrData := _Safe(ADoc)^;

    // Array 타입인지 확인
    if not (dvoIsArray in arrData.Options) then
      raise EJsonException.Create('ADoc is not a JSON Array');

    // JSON 문자열로 직렬화 후 TJsonArray로 파싱
    LJson := arrData.ToJson;
    Result := TJsonArray(TJSONObject.ParseJSONValue(LJson));

//    for rowVar in arrData as TDocVariant do
//    begin
//      rowData := TDocVariantData(rowVar);
//      jObj := TJSONObject.Create;
//      try
//        // 오브젝트 타입인지 확인
//        if dvoIsObject in rowData.Options then
//        begin
//          for i := 0 to rowData.Count - 1 do
//          begin
//            name := UTF8ToString(rowData.Names[i]);
//            val  := UTF8ToString(VariantToUtf8(rowData.Values[i]));
//            jObj.AddPair(name, TJSONString.Create(val));
//          end;
//        end;
//        jArr.AddElement(jObj);
//        jObj := nil; // 소유권 이전 후 nil 처리
//      except
//        jObj.Free;
//        raise;
//      end;
//    end;

//    Result := jArr;
  except
    jArr.Free;
    raise;
  end;
end;

class function TMormot_Json.DocVariantToJsonArrayViaJson(
  const ADoc: variant): TJSONArray;
var
  jsonStr : RawUtf8;
  parsed  : TJSONValue;
begin
  Result := nil;

  // TDocVariantData → JSON 문자열
  jsonStr := VariantToUtf8(ADoc);

  // JSON 문자열 → TJSONArray
  parsed := TJSONObject.ParseJSONValue(string(jsonStr));
  if parsed is TJSONArray then
    Result := TJSONArray(parsed)
  else
  begin
    parsed.Free;
    Result := TJSONArray.Create; // 파싱 실패 시 빈 배열
  end;
end;

end.
