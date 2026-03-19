unit UnitIniAttriPersist;

interface

uses SysUtils,Classes, Rtti, TypInfo, IniFiles;

type
  JHPIniAttribute = class(TCustomAttribute)
  private
    FSection: string;
    FName: string;
    FTypeKind: TTypeKind;
    FDefaultValue: string;
    FTagNoOrCompName: string;
  published
    constructor Create(const aSection : String; const aName : string;
      const aDefaultValue, aTagNoOrCompName : String;const ATypeKind: TTypeKind);

    property Section : string read FSection write FSection;
    property Name : string read FName write FName;
    property TypeKind : TTypeKind read FTypeKind write FTypeKind;
    property DefaultValue : string read FDefaultValue write FDefaultValue;
    property TagNoOrCompName : string read FTagNoOrCompName write FTagNoOrCompName;
  end;

  EJHPIniPersist = class(Exception);

  TJHPIniPersist = class (TObject)
  public
    //AValue를 AKind 로 TypeCast하여 반환함.
    class function ConvertValueFromTypeKind(AValue: TValue; aTargetTypeKind: TTypeKind): TValue;
//    class procedure SetValue();
    class function GetValueFromIni(AIniFile: TIniFile; AAttri: JHPIniAttribute) : TValue;
    class procedure Write2Ini(AIniFile: TIniFile; AAttri: JHPIniAttribute; aValue : TValue);
    class function GetIniAttribute(Obj : TRttiObject) : JHPIniAttribute;
    class procedure Load(FileName : String;obj : TObject);
    class procedure Save(FileName : String;obj : TObject);
  end;

function CastTValueByKind(const AValue: TValue; AKind: TTypeKind): TValue;

implementation

{ TJHPIniPersist }

class function TJHPIniPersist.ConvertValueFromTypeKind(AValue: TValue;
  aTargetTypeKind: TTypeKind): TValue;
var
  V: Variant;
begin
  V := AValue.AsVariant;

  case aTargetTypeKind of
    tkInteger:
      Result := TValue.From<Integer>(Integer(V));

    tkInt64:
      Result := TValue.From<Int64>(Int64(V));

    tkFloat:
      Result := TValue.From<Double>(Double(V));

    tkString, tkLString, tkWString, tkUString:
      Result := TValue.From<string>(string(V));

    tkEnumeration:
      Result := TValue.FromOrdinal(AValue.TypeInfo, Integer(V));

    tkVariant:
      Result := TValue.From<Variant>(V);

  else
    raise Exception.CreateFmt('Unsupported conversion to %s',
      [GetEnumName(TypeInfo(TTypeKind), Ord(aTargetTypeKind))]);
  end;
end;

class function TJHPIniPersist.GetIniAttribute(
  Obj: TRttiObject): JHPIniAttribute;
var
  Attr: TCustomAttribute;
begin
  for Attr in Obj.GetAttributes do
  begin
    if Attr is JHPIniAttribute then
    begin
      exit(JHPIniAttribute(Attr));
    end;
  end;

  result := nil;
end;

class function TJHPIniPersist.GetValueFromIni(AIniFile: TIniFile; AAttri: JHPIniAttribute) : TValue;
begin
  case AAttri.TypeKind of
    tkWChar,
    tkLString,
    tkWString,
    tkString,
    tkChar,
    tkUString    : Result := AIniFile.ReadString(AAttri.Section, AAttri.Name, AAttri.DefaultValue);
    tkInteger    : Result := AIniFile.ReadInteger(AAttri.Section, AAttri.Name, 0);
    tkInt64      : Result := AIniFile.ReadInteger(AAttri.Section, AAttri.Name, 0);
    tkFloat      : Result := AIniFile.ReadFloat(AAttri.Section, AAttri.Name, 0.0);
    tkEnumeration: Result := AIniFile.ReadBool(AAttri.Section, AAttri.Name, False);
//    tkSet: begin
//             i :=  StringToSet(aValue.TypeInfo,aData);
//             TValue.Make(@i, aValue.TypeInfo, aValue);
//          end;
    else
      raise EJHPIniPersist.Create('Type not Supported');
  end;
end;

class procedure TJHPIniPersist.Load(FileName: String; obj: TObject);
var
  ctx : TRttiContext;
  objType : TRttiType;
  Field : TRttiField;
  Prop  : TRttiProperty;
  IniValue, Value : TValue;
  IniAttr : JHPIniAttribute;
  IniFile : TIniFile;
begin
  ctx := TRttiContext.Create;
  try
    IniFile := TIniFile.Create(FileName);
    try
      objType := ctx.GetType(Obj.ClassInfo);

      for Prop in objType.GetProperties do
      begin
        IniAttr := GetIniAttribute(Prop);

        if Assigned(IniAttr) then
        begin
          IniValue := TJHPIniPersist.GetValueFromIni(IniFile, IniAttr);
          Value := Prop.GetValue(Obj);
          Value := IniValue;
          Prop.SetValue(Obj,Value);
        end;
      end;
    finally
      IniFile.Free;
    end;
  finally
    ctx.Free;
  end;
end;

class procedure TJHPIniPersist.Save(FileName: String; obj: TObject);
var
  ctx : TRttiContext;
  objType : TRttiType;
  Field : TRttiField;
  Prop  : TRttiProperty;
  Value : TValue;
  IniAttr : JHPIniAttribute;
  IniFile : TIniFile;
  Data : String;
begin
  ctx := TRttiContext.Create;
  try
    IniFile := TIniFile.Create(FileName);
    try
      objType := ctx.GetType(Obj.ClassInfo);

      for Prop in objType.GetProperties do
      begin
        IniAttr := GetIniAttribute(Prop);

        if Assigned(IniAttr) then
        begin
          Value := Prop.GetValue(Obj);
          TJHPIniPersist.Write2Ini(IniFile, IniAttr, Value);
        end;
      end;
    finally
      IniFile.Free;
    end;
  finally
    ctx.Free;
  end;
end;

class procedure TJHPIniPersist.Write2Ini(AIniFile: TIniFile;
  AAttri: JHPIniAttribute; aValue : TValue);
begin
  case AAttri.TypeKind of
    tkWChar,
    tkLString,
    tkWString,
    tkString,
    tkChar,
    tkUString    : AIniFile.WriteString(AAttri.Section, AAttri.Name, aValue.AsString);
    tkInteger    : AIniFile.WriteInteger(AAttri.Section, AAttri.Name, aValue.AsInteger);
    tkInt64      : AIniFile.WriteInteger(AAttri.Section, AAttri.Name, aValue.AsInt64);
    tkFloat      : AIniFile.WriteFloat(AAttri.Section, AAttri.Name, aValue.AsExtended);
    tkEnumeration: AIniFile.WriteBool(AAttri.Section, AAttri.Name, aValue.AsBoolean);
//    tkSet: begin
//             i :=  StringToSet(aValue.TypeInfo,aData);
//             TValue.Make(@i, aValue.TypeInfo, aValue);
//          end;
    else
      raise EJHPIniPersist.Create('Type not Supported');
  end;
end;

{ JHPIniAttribute }

constructor JHPIniAttribute.Create(const aSection, aName, aDefaultValue, aTagNoOrCompName: String;
  const ATypeKind: TTypeKind);
begin
  FSection := aSection;
  FName := aName;
  FTypeKind := ATypeKind;
  FDefaultValue := aDefaultValue;
  TagNoOrCompName := aTagNoOrCompName;
end;

function CastTValueByKind(const AValue: TValue; AKind: TTypeKind): TValue;
begin
  case AKind of
    tkInteger:
      Result := TValue.From<Integer>(AValue.AsInteger);

    tkInt64:
      Result := TValue.From<Int64>(AValue.AsInt64);

    tkFloat:
      Result := TValue.From<Double>(AValue.AsExtended);

    tkString, tkLString, tkWString, tkUString:
      Result := TValue.From<string>(AValue.AsString);

    tkChar, tkWChar:
      Result := TValue.From<Char>(AValue.AsType<Char>);

    tkEnumeration:
      Result := TValue.FromOrdinal(AValue.TypeInfo, AValue.AsOrdinal);

    tkClass:
      Result := TValue.From<TObject>(AValue.AsObject);

    tkClassRef:
      Result := TValue.From<TClass>(AValue.AsType<TClass>);

    tkPointer:
      Result := TValue.From<Pointer>(AValue.AsType<Pointer>);

    tkSet:
      Result := TValue.FromOrdinal(AValue.TypeInfo, AValue.AsOrdinal);

    tkVariant:
      Result := TValue.From<Variant>(AValue.AsVariant);

    tkRecord:
      Result := AValue; // record는 그대로 반환

    tkInterface:
      Result := TValue.From<IInterface>(AValue.AsInterface);

    tkDynArray:
      Result := AValue; // dynamic array는 그대로

  else
    raise Exception.CreateFmt('Unsupported TTypeKind: %d', [Ord(AKind)]);
  end;
end;

end.
