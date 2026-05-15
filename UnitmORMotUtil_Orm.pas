unit UnitmORMotUtil_Orm;

interface

uses System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections,
  mormot.core.base, mormot.core.rtti, mormot.core.text, mormot.core.unicode,
  mormot.core.variants, mormot.core.json,
  mormot.orm.core, mormot.orm.base, mormot.rest.sqlite3, mormot.db.raw.sqlite3;

type
  TOrmRecordMapItem = record
    Prop: TRttiProperty;
    Field: TRttiField;
  end;

  TOrmRecordMapper = class
  private
    class var FCache: TObjectDictionary<string,TArray<TOrmRecordMapItem>>;
    class function BuildMap(AOrmClass: TClass; ARecType: PTypeInfo): TArray<TOrmRecordMapItem>;
  public
    class constructor Create;
    class destructor Destroy;

    class procedure FastAssignRecordToOrm<T: record>(AOrm: TOrm; const ARec: T);
  end;

  TOrmUtil = class
    class function AddOrUpdateOrm<T:TOrm>(const AOrm: T; const AIsUpdate: Boolean; ADB: TRestClientDB): integer; static;
    class function DeleteOrm<T:TOrm>(const AID: TID; const AIsUpdate: Boolean; ADB: TRestClientDB): Boolean; static;
    class procedure AssignRecordToOrm<T: record>(const ARec: T; AOrm: TOrm); static;
    //mORMot2 native RTTI 방식
    //**TOrmProps와 TOrmPropInfo**를 이용해 이미 생성된 ORM 메타데이터를 사용
    class procedure AssignRecordToOrmNative<T: record>(AOrm: TOrm; const ARec: T); static;

    class procedure AssignOrmToRecordNative<T: record>(AOrm: TOrm; var ARec: T); static;
    /// INSERT / UPDATE / DELETE 전용 실행 함수
    /// @param DB      TSqlDatabase 인스턴스
    /// @param SQL     실행할 SQL ('INSERT INTO t(a,b) VALUES(?,?)')
    /// @param Params  ? 에 순서대로 바인딩될 파라미터 배열
    /// @returns       영향받은 행 수
    class function ExecuteNonQuery(DB: TSqlDatabase;
      const SQL: RawUtf8;
      const Params: array of const): integer;
    class function QueryToDocVariant(DB: TSqlDatabase;
      const SQL: RawUtf8;
      const Params: array of const): variant;
    class function QueryToJsonAry(DB: TSqlDatabase;
      const SQL: RawUtf8;
      const Params: array of const): RawUtf8;
    class function QueryToJsonAryByWriter(DB: TSqlDatabase;
      const SQL: RawUtf8;
      const Params: array of const): RawUtf8;
  end;

implementation

uses UnitStringUtil;


{ TOrmUtil }

class function TOrmUtil.AddOrUpdateOrm<T>(const AOrm: T; const AIsUpdate: Boolean;
  ADB: TRestClientDB): integer;
begin
  Result := -1;

  if AIsUpdate then
  begin
    Result := Ord(ADB.Update(AOrm));
  end
  else
  begin
    Result := ADB.Add(AOrm, true);
  end;
end;

class procedure TOrmUtil.AssignOrmToRecordNative<T>(AOrm: TOrm; var ARec: T);
var
  props: TOrmProperties;
  prop: TOrmPropInfo;
  ctx: TRttiContext;
  recType: TRttiType;
  field: TRttiField;
  recValue: TValue;
  v: TValue;
  i: Integer;
begin
  props := AOrm.OrmProps;

  ctx := TRttiContext.Create;
  recType := ctx.GetType(TypeInfo(T));

  recValue := TValue.From<T>(ARec);

  for i := 0 to props.Fields.Count - 1 do
  begin
    prop := props.Fields.List[i];

    // PK skip
    if prop.Name = 'ID' then
      Continue;

    field := recType.GetField(String(prop.Name));
    if field = nil then
      Continue;

    // ORM property → TValue
    v := prop.GetValue(AOrm, True);

    // record field에 값 할당
    field.SetValue(recValue.GetReferenceToRawData, v);
  end;

  // record 반영
  ARec := recValue.AsType<T>;
end;

class procedure TOrmUtil.AssignRecordToOrm<T>(const ARec: T; AOrm: TOrm);
var
  ctx: TRttiContext;
  ormType: TRttiType;
  recType: TRttiType;
  prop: TRttiProperty;
  field: TRttiField;
  recValue: TValue;
  fieldValue: TValue;
begin
  ctx := TRttiContext.Create;

  ormType := ctx.GetType(AOrm.ClassType);
  recType := ctx.GetType(TypeInfo(T));

  recValue := TValue.From<T>(ARec);

  for prop in ormType.GetProperties do
  begin
    if (prop.Visibility = mvPublished) and prop.IsWritable then
    begin
      // PK skip
      if prop.Name = 'ID' then
        Continue;

      if prop.Name = 'RowID' then
        Continue;

      field := recType.GetField(prop.Name);

      if Assigned(field) then
      begin
        fieldValue := field.GetValue(recValue.GetReferenceToRawData);
        prop.SetValue(AOrm, fieldValue);
      end;
    end;
  end;
end;

class procedure TOrmUtil.AssignRecordToOrmNative<T>(AOrm: TOrm; const ARec: T);
var
  props: TOrmProperties;
  prop: TOrmPropInfo;
  ctx: TRttiContext;
  recType: TRttiType;
  field: TRttiField;
  recValue, V: TValue;
  i: Integer;
  s: RawUtf8;
begin
  props := AOrm.OrmProps;

  ctx := TRttiContext.Create;
  recType := ctx.GetType(TypeInfo(T));
  recValue := TValue.From<T>(ARec);

  for i := 0 to props.Fields.Count - 1 do
  begin
    prop := props.Fields.List[i];

    // PK skip
    if prop.Name = 'ID' then
      Continue;

    field := recType.GetField(String(prop.Name));

    if field = nil then
      Continue;

    v := field.GetValue(recValue.GetReferenceToRawData);
    s := RawUtf8(v.AsString);
    prop.SetValue(AOrm, PUtf8Char(s), Length(s), False);
//    prop.SetValue(AOrm, field.GetValue(recValue.GetReferenceToRawData));
  end;
end;

class function TOrmUtil.DeleteOrm<T>(const AID: TID; const AIsUpdate: Boolean;
  ADB: TRestClientDB): Boolean;
begin
  Result := False;

  if AIsUpdate then
  begin
    Result := ADB.Delete(T, AID);
  end
end;

class function TOrmUtil.ExecuteNonQuery(DB: TSqlDatabase; const SQL: RawUtf8;
  const Params: array of const): integer;
var
  Req: TSqlRequest;
  i: integer;
begin
  Result := 0;

  // SELECT 실행 방지
  if IdemPChar(Pointer(TrimU(SQL)), 'SELECT') then
    raise ESqlite3Exception.Create('ExecuteNonQuery: SELECT는 허용되지 않습니다.');

  if DB = nil then
    raise ESqlite3Exception.Create('ExecuteNonQuery: DB가 nil입니다.');

  Req.Prepare(DB.DB, SQL);
  try
    // 파라미터 바인딩 (1-based)
    for i := 0 to High(Params) do
    begin
      case Params[i].VType of
        vtInteger:
          Req.Bind(i + 1, Params[i].VInteger);

        vtInt64:
          Req.Bind(i + 1, Params[i].VInt64^);

        vtExtended:
          Req.Bind(i + 1, Params[i].VExtended^);

        vtAnsiString:
          Req.BindS(i + 1, RawUtf8(Params[i].VAnsiString));

        vtUnicodeString:
          Req.BindS(i + 1, RawUtf8(UnicodeString(Params[i].VUnicodeString)));

        vtWideString:
          Req.BindS(i + 1, RawUnicodeToUtf8(
            Params[i].VWideString,
            Length(WideString(Params[i].VWideString))));

        vtBoolean:
          Req.Bind(i + 1, Ord(Params[i].VBoolean));

        vtPointer:
          if Params[i].VPointer = nil then
            Req.BindNull(i + 1)  // nil → NULL
          else
            raise ESqlite3Exception.CreateFmt(
              'ExecuteNonQuery: 지원하지 않는 포인터 파라미터 (index=%d)', [i]);
      else
        raise ESqlite3Exception.CreateFmt(
          'ExecuteNonQuery: 지원하지 않는 파라미터 타입 %d (index=%d)',
          [Params[i].VType, i]);
      end;
    end;

    // 실행 (SQLITE_DONE 까지 Step 반복)
    Req.ExecuteAll;

    // 영향받은 행 수
    Result := DB.LastChangeCount;

  finally
    Req.Close; // Statement 반드시 해제
  end;
end;

class function TOrmUtil.QueryToDocVariant(DB: TSqlDatabase; const SQL: RawUtf8;
  const Params: array of const): variant;
var
  req     : TSqlRequest;
  resArr  : TDocVariantData;   // JSON Array 역할
  rowObj  : TDocVariantData;   // JSON Object (한 행)
  i       : Integer;
  colName : RawUtf8;
  colVal  : RawUtf8;
begin
  // 빈 배열로 초기화
  resArr.InitArray([], JSON_FAST_FLOAT);

  if SQL = '' then
  begin
    Result := variant(resArr);
    Exit;
  end;

  if DB = nil then
    raise ESqlite3Exception.Create('ExecuteNonQuery: DB가 nil입니다.');

  Req.Prepare(DB.DB, SQL);
  try
    // 파라미터 바인딩 (1-based)
    for i := 0 to High(Params) do
    begin
      case Params[i].VType of
        vtInteger:
          Req.Bind(i + 1, Params[i].VInteger);

        vtInt64:
          Req.Bind(i + 1, Params[i].VInt64^);

        vtExtended:
          Req.Bind(i + 1, Params[i].VExtended^);

        vtAnsiString:
          Req.BindS(i + 1, RawUtf8(Params[i].VAnsiString));

        vtUnicodeString:
          Req.BindS(i + 1, RawUtf8(UnicodeString(Params[i].VUnicodeString)));

        vtWideString:
          Req.BindS(i + 1, RawUnicodeToUtf8(
            Params[i].VWideString,
            Length(WideString(Params[i].VWideString))));

        vtBoolean:
          Req.Bind(i + 1, Ord(Params[i].VBoolean));

        vtPointer:
          if Params[i].VPointer = nil then
            Req.BindNull(i + 1)  // nil → NULL
          else
            raise ESqlite3Exception.CreateFmt(
              'ExecuteNonQuery: 지원하지 않는 포인터 파라미터 (index=%d)', [i]);
      else
        raise ESqlite3Exception.CreateFmt(
          'ExecuteNonQuery: 지원하지 않는 파라미터 타입 %d (index=%d)',
          [Params[i].VType, i]);
      end;
    end;//for

  while req.Step = SQLITE_ROW do
  begin
    rowObj.InitObject([], JSON_FAST_FLOAT);

    for i := 0 to req.FieldCount - 1 do
    begin
      colName := req.FieldName(i);
      req.FieldUtf8(i, colVal);
      rowObj.AddValue(colName, colVal);
    end;

    resArr.AddItem(variant(rowObj));
  end; //while

  Result := variant(resArr);

//  TDocVariantData(Result).Values[0].name; // 첫 행의 name 필드
  finally
    Req.Close; // Statement 반드시 해제
  end;
end;

class function TOrmUtil.QueryToJsonAry(DB: TSqlDatabase; const SQL: RawUtf8;
  const Params: array of const): RawUtf8;
begin
  Result := VariantToUtf8(QueryToDocVariant(DB, SQL, Params));
end;

class function TOrmUtil.QueryToJsonAryByWriter(DB: TSqlDatabase;
  const SQL: RawUtf8; const Params: array of const): RawUtf8;
var
  req     : TSqlRequest;
  writer  : TJsonWriter;
  temp    : TTextWriterStackBuffer; // 스택 버퍼 (힙 할당 최소화)
  i       : Integer;
  LUtf8: RawUtf8;
begin
  Result := '[]';
  if SQL = '' then Exit;

  req.Prepare(db.DB, SQL);
  try
    writer := TJsonWriter.CreateOwnedStream(temp);
    try
      writer.Add('[');   // 배열 시작

      while req.Step = SQLITE_ROW do
      begin
        writer.Add('{');  // 오브젝트 시작

        for i := 0 to req.FieldCount - 1 do
        begin
          // "컬럼명":"값"
          writer.AddProp(pointer(req.FieldName(i)));
          writer.AddString('"');
          req.FieldUtf8(i,LUtf8);
          writer.AddJsonEscape(pointer(LUtf8));
          writer.AddString('"');
          if i < req.FieldCount - 1 then
            writer.Add(',');
        end;

        writer.Add('}');  // 오브젝트 종료
        writer.Add(',');  // 행 구분자 (마지막은 나중에 제거)
      end;

      writer.CancelLastComma; // 마지막 쉼표 제거
      writer.Add(']');   // 배열 종료
      writer.SetText(Result);
    finally
      writer.Free;
    end;
  finally
    req.Close;
  end;
end;

{ TOrmRecordMapper }

class function TOrmRecordMapper.BuildMap(
  AOrmClass: TClass;
  ARecType: PTypeInfo): TArray<TOrmRecordMapItem>;
var
  ctx: TRttiContext;
  ormType: TRttiType;
  recType: TRttiType;
  prop: TRttiProperty;
  field: TRttiField;
  list: TList<TOrmRecordMapItem>;
  item: TOrmRecordMapItem;
begin
  ctx := TRttiContext.Create;

  ormType := ctx.GetType(AOrmClass);
  recType := ctx.GetType(ARecType);

  list := TList<TOrmRecordMapItem>.Create;
  try
    for prop in ormType.GetProperties do
      if (prop.Visibility = mvPublished) and prop.IsWritable then
      begin
         //RMot primary key skip
        if SameText(prop.Name, 'ID') then
          Continue;

        if SameText(prop.Name, 'RowID') then
          Continue;

        field := recType.GetField(prop.Name);
        if field <> nil then
        begin
          item.Prop := prop;
          item.Field := field;
          list.Add(item);
        end;
      end;

    Result := list.ToArray;
  finally
    list.Free;
  end;
end;

class constructor TOrmRecordMapper.Create;
begin
  FCache := TObjectDictionary<string,TArray<TOrmRecordMapItem>>.Create([doOwnsValues]);
end;

class destructor TOrmRecordMapper.Destroy;
begin
  FCache.Free;
end;

class procedure TOrmRecordMapper.FastAssignRecordToOrm<T>(AOrm: TOrm;
  const ARec: T);
var
  key: string;
  map: TArray<TOrmRecordMapItem>;
  recValue: TValue;
  item: TOrmRecordMapItem;
  val: TValue;
begin
  if not Assigned(FCache) then
    FCache := TObjectDictionary<string,TArray<TOrmRecordMapItem>>.Create([doOwnsValues]);

  try
    key := AOrm.ClassName + ':' + PTypeInfo(TypeInfo(T)).Name;

    if not FCache.TryGetValue(key, map) then
    begin
      map := BuildMap(AOrm.ClassType, TypeInfo(T));
      FCache.Add(key, map);
    end;

    recValue := TValue.From<T>(ARec);

    for item in map do
    begin
      val := item.Field.GetValue(recValue.GetReferenceToRawData);
      item.Prop.SetValue(AOrm, val);
    end;
  finally
    FreeAndNil(FCache);
  end;
end;

end.
