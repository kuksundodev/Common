unit UnitmORMotUtil_Orm;

interface

uses System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections,
  mormot.core.base, mormot.core.rtti, mormot.core.text, mormot.orm.core,
  mormot.orm.base, mormot.rest.sqlite3;

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
    class procedure AddOrUpdateOrm<T:TOrm>(const AOrm: T; const AIsUpdate: Boolean; ADB: TRestClientDB); static;
    class procedure AssignRecordToOrm<T: record>(const ARec: T; AOrm: TOrm); static;
    //mORMot2 native RTTI 방식
    //**TOrmProps와 TOrmPropInfo**를 이용해 이미 생성된 ORM 메타데이터를 사용
    class procedure AssignRecordToOrmNative<T: record>(AOrm: TOrm; const ARec: T); static;

    class procedure AssignOrmToRecordNative<T: record>(AOrm: TOrm; var ARec: T); static;
  end;

implementation

uses UnitStringUtil;


{ TOrmUtil }

class procedure TOrmUtil.AddOrUpdateOrm<T>(const AOrm: T; const AIsUpdate: Boolean;
  ADB: TRestClientDB);
begin
  if AIsUpdate then
  begin
    ADB.Update(AOrm);
  end
  else
  begin
    ADB.Add(AOrm, true);
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
