unit UnitAccessDBUtil;

{
  ============================================================================
  mORMot2 + OleDB(ACE) 를 이용한 Access(.accdb/.mdb) 데이터 액세스 모듈
  ============================================================================
  - mORMot2에서 OleDB 연결 속성 클래스는 TSqlDBOleDBConnectionProperties 입니다.
    (mORMot1의 TOleDBConnectionProperties에 해당하는 mORMot2 이름)
    유닛: mormot.db.sql.oledb.pas
  - 문(Statement)은 Props.NewThreadSafeStatement 로 얻는 TSqlDBStatement 를
    사용하며, 사용 후 반드시 Free 해야 합니다.
  - .accdb 는 반드시 "Microsoft.ACE.OLEDB.12.0" 드라이버가 필요합니다.
    드라이버는 프로젝트 Platform(Win32/Win64)과 반드시 일치해야 합니다.
    (32비트 프로젝트 -> ACE 32비트, 64비트 프로젝트 -> ACE 64비트)
  - 정확한 메서드 시그니처(Execute/Step/ColumnXxx 등)는 사용 중인 mORMot2
    버전에 따라 약간 다를 수 있으니, mormot.db.sql.pas 의 TSqlDBStatement
    선언을 한 번 확인해 보시길 권장합니다.
  ============================================================================
}

interface

uses
  SysUtils,
  Classes,
  mormot.core.base,
  mormot.core.text,
  mormot.db.core,
  mormot.db.sql,
  mormot.db.sql.oledb;

type
  TAccessDB = class
  private
    fProps: TSqlDBOleDBConnectionProperties;
  public
    // aAccdbPath: 예) 'C:\Data\MyDB.accdb'
    constructor Create(const aAccdbPath: string);
    destructor Destroy; override;

    // 조회 - 반환된 Stmt는 사용 후 반드시 Free 할 것
    //   예) Stmt := DB.Select('SELECT * FROM Customers WHERE ID=?', [123]);
    function Select(const aSQL: RawUtf8;
      const aParams: array of const): TSqlDBStatement;

    // 입력
    //   예) DB.Insert('Customers', ['Name','Email'], ['홍길동','a@b.com']);
    procedure Insert(const aTable: RawUtf8;
      const aFields: array of RawUtf8; const aValues: array of const);

    // 수정
    //   예) DB.Update('Customers', 'Name=?, Email=?', 'ID=?', ['홍길동','a@b.com', 123]);
    procedure Update(const aTable, aSetSQL, aWhereSQL: RawUtf8;
      const aParams: array of const);

    // 삭제
    //   예) DB.Delete('Customers', 'ID=?', [123]);
    procedure Delete(const aTable, aWhereSQL: RawUtf8;
      const aParams: array of const);

    property Props: TSqlDBOleDBConnectionProperties read fProps;
  end;

implementation

{ TAccessDB }

constructor TAccessDB.Create(const aAccdbPath: string);
var
  connStr: RawUtf8;
begin
  inherited Create;
  connStr := StringToUtf8(Format(
    'Provider=Microsoft.ACE.OLEDB.12.0;Data Source=%s;Persist Security Info=False;',
    [aAccdbPath]));
  // 두 번째~네 번째 파라미터(DatabaseName/UserID/Password)는 OleDB 연결
  // 문자열에 이미 다 포함되므로 비워둡니다.
  fProps := TSqlDBOleDBConnectionProperties.Create(connStr, '', '', '');
end;

destructor TAccessDB.Destroy;
begin
  fProps.Free;
  inherited;
end;

function TAccessDB.Select(const aSQL: RawUtf8;
  const aParams: array of const): TSqlDBStatement;
begin
  Result := fProps.NewThreadSafeStatement;
  try
    Result.Execute(aSQL, true, aParams);
  except
    Result.Free;
    raise;
  end;
end;

procedure TAccessDB.Insert(const aTable: RawUtf8;
  const aFields: array of RawUtf8; const aValues: array of const);
var
  Stmt: TSqlDBStatement;
  sql, fieldsList, paramsList: RawUtf8;
  i: integer;
begin
  fieldsList := '';
  paramsList := '';
  for i := 0 to High(aFields) do
  begin
    if i > 0 then
    begin
      fieldsList := fieldsList + ',';
      paramsList := paramsList + ',';
    end;
    fieldsList := fieldsList + aFields[i];
    paramsList := paramsList + '?';
  end;
  sql := 'INSERT INTO ' + aTable + ' (' + fieldsList + ') VALUES (' + paramsList + ')';
  Stmt := fProps.NewThreadSafeStatement;
  try
    Stmt.Execute(sql, false, aValues);
  finally
    Stmt.Free;
  end;
end;

procedure TAccessDB.Update(const aTable, aSetSQL, aWhereSQL: RawUtf8;
  const aParams: array of const);
var
  Stmt: TSqlDBStatement;
  sql: RawUtf8;
begin
  sql := 'UPDATE ' + aTable + ' SET ' + aSetSQL;
  if aWhereSQL <> '' then
    sql := sql + ' WHERE ' + aWhereSQL;
  Stmt := fProps.NewThreadSafeStatement;
  try
    Stmt.Execute(sql, false, aParams);
  finally
    Stmt.Free;
  end;
end;

procedure TAccessDB.Delete(const aTable, aWhereSQL: RawUtf8;
  const aParams: array of const);
var
  Stmt: TSqlDBStatement;
  sql: RawUtf8;
begin
  sql := 'DELETE FROM ' + aTable;
  if aWhereSQL <> '' then
    sql := sql + ' WHERE ' + aWhereSQL;
  Stmt := fProps.NewThreadSafeStatement;
  try
    Stmt.Execute(sql, false, aParams);
  finally
    Stmt.Free;
  end;
end;

end.
