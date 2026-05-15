unit UnitmORMotUtil_MariaDB;

interface

uses math, SysUtils,
  mormot.core.base,
  mormot.core.unicode,
  mormot.core.json,
  mormot.core.variants,
  mormot.core.text,      // HexToBin, TrimSelf
  mormot.crypt.core,    // TAesEcb, TAes
  mormot.db.sql,
  mormot.db.raw.sqlite3, // TSqlDatabase, TSqlRequest
  mormot.db.raw.sqlite3.static; // 정적 SQLite 링크

type
  TMormot_MariaDB = class
    //Anti-Gravity 생성
    /// <summary>
    /// MariaDB의 HEX(AES_ENCRYPT(PlainText, PW)) 와 동일하게 동작하는 함수
    /// </summary>
    /// <param name="PlainText">암호화할 일반 텍스트</param>
    /// <param name="PW">암호화에 사용할 비밀번호(Key)</param>
    class function MariaDB_AesEncrypt(const PlainText, PW: RawUtf8): RawUtf8;
    /// <summary>
    /// MariaDB의 convert(AES_DECRYPT(UnHex(HexPass),PW) using utf8)와 동일하게 동작하는 함수
    /// </summary>
    /// <param name="HexPass">UnHex 처리 전의 순수 Hex 문자열 (예: 'A1B2C3...')</param>
    /// <param name="PW">복호화에 사용할 비밀번호(Key)</param>
    class function MariaDB_AesDecrypt(const HexPass, PW: RawUtf8): RawUtf8;

    /// MariaDB 테이블/컬럼 식별자 유효성 검사
    /// 규칙:
    ///   - 빈 문자열 불가
    ///   - 최대 64자 (MariaDB 제한)
    ///   - 허용 문자: 영문자(A-Z, a-z), 숫자(0-9), 언더스코어(_), 달러($)
    ///   - 첫 글자는 숫자 불가
    ///   - MariaDB 예약어 차단 (옵션)
    class function IsValidIdentifier(const aName: RawUtf8;
      aCheckReserved: Boolean = True): Boolean;

    /// 원격 MariaDB 테이블 구조를 JSON으로 반환
    /// @param aConnection  이미 연결된 TSqlDBConnection 인스턴스
    /// @param aTableName   조회할 테이블 이름
    /// @returns JSON 문자열 (컬럼 정보 배열)
    class function GetTableStructureAsJson(
      aConnection: TSqlDBConnection;
      const aTableName: RawUtf8): RawUtf8;

    // ──────────────────────────────────────────────
    // MariaDB 타입 → SQLite 타입 변환
    // ──────────────────────────────────────────────
    class function MariaDbTypeToSQLite(const aMariaType: RawUtf8): RawUtf8;
    // ──────────────────────────────────────────────
    // MariaDB DEFAULT 값 → SQLite DEFAULT 값 변환
    // ──────────────────────────────────────────────
    class function ConvertDefaultValue(
      const aDefault  : RawUtf8;
      const aSqliteType: RawUtf8): RawUtf8;
    // ──────────────────────────────────────────────
    // 메인 변환 함수
    // MariaDB JSON 구조 → SQLite JSON 구조
    // ──────────────────────────────────────────────
    function ConvertMariaDbJsonToSQLiteJson(const aMariaJson: RawUtf8): RawUtf8;
  end;

implementation

{ TMormot_MariaDB }

class function TMormot_MariaDB.ConvertDefaultValue(const aDefault,
  aSqliteType: RawUtf8): RawUtf8;
var
  up: RawUtf8;
begin
  if aDefault = '' then
    Exit('');

  up := UpperCase(aDefault);

  // MariaDB 함수 → SQLite 함수 매핑
  if (up = 'CURRENT_TIMESTAMP') or
     (up = 'NOW()')             or
     (up = 'LOCALTIME')        or
     (up = 'LOCALTIMESTAMP')   then
    Exit('CURRENT_TIMESTAMP');

  if up = 'CURRENT_DATE' then Exit('CURRENT_DATE');
  if up = 'CURRENT_TIME' then Exit('CURRENT_TIME');

  // NULL 리터럴
  if up = 'NULL' then Exit('NULL');

  // 숫자 타입이면 따옴표 없이
  if (Pos(aSqliteType, 'INTEGER') > 0) or
      (Pos(aSqliteType, 'REAL') > 0) or
      (Pos(aSqliteType, 'NUMERIC') > 0) then
  begin
    // 숫자인지 확인
    if (aDefault <> '') and
       (aDefault[1] in ['0'..'9', '-', '+']) then
      Exit(aDefault);
  end;

  // 그 외는 작은따옴표로 감싸기 (이미 감싸진 경우 제외)
  if (Length(aDefault) >= 2) and
     (aDefault[1] = '''') and
     (aDefault[Length(aDefault)] = '''') then
    Exit(aDefault);

  Result := QuotedStr(aDefault);  // 'value'

end;

function TMormot_MariaDB.ConvertMariaDbJsonToSQLiteJson(
  const aMariaJson: RawUtf8): RawUtf8;
var
  src         : TDocVariantData;  // 입력 파싱
  dst         : TDocVariantData;  // 출력 빌드
  srcCols     : TDocVariantData;  // columns 배열
  srcIdxs     : TDocVariantData;  // indexes 배열
  dstCols     : TDocVariantData;  // 변환된 columns
  dstIdxs     : TDocVariantData;  // 변환된 indexes
  col         : TDocVariantData;  // 개별 컬럼
  idx         : TDocVariantData;  // 개별 인덱스
  newCol      : TDocVariantData;
  newIdx      : TDocVariantData;
  i           : Integer;
  mariaType   : RawUtf8;
  sqliteType  : RawUtf8;
  defVal      : RawUtf8;
  colName     : RawUtf8;
  isNullable  : Boolean;
  isPK        : Boolean;
  colKey      : RawUtf8;
  extra       : RawUtf8;
  isAutoInc   : Boolean;
  comment     : RawUtf8;
  tableName   : RawUtf8;
  columns   : RawUtf8;
  indexes   : RawUtf8;
begin
  Result := '';

  // ── 1. 입력 JSON 파싱 ──
  if not src.InitJson(aMariaJson, JSON_OPTIONS_FAST) then
    raise EDocVariant.Create('Invalid MariaDB JSON input');

  tableName := src.U['table'];

  // ── 2. columns 배열 파싱 ──
  columns := src.U['columns'];
  srcCols.InitJson(columns, JSON_OPTIONS_FAST);
  dstCols.InitArray([], JSON_OPTIONS_FAST);

  for i := 0 to srcCols.Count - 1 do
  begin
    col.InitJson(VariantToUtf8(srcCols.Values[i]), JSON_OPTIONS_FAST);

    colName    := col.U['name'];
    mariaType  := col.U['type'];
    isNullable := col.B['nullable'];
    colKey     := col.U['key'];
    extra      := LowerCase(col.U['extra']);
    isAutoInc  := Pos('auto_increment', extra) > 0;
    isPK       := SameTextU(colKey, 'PRI');
    comment    := col.U['comment'];

    // 타입 변환
    sqliteType := MariaDbTypeToSQLite(mariaType);

    // DEFAULT 처리
    if col.GetValueIndex('default') >= 0 then
      defVal := col.U['default']
    else
      defVal := '';

    defVal := ConvertDefaultValue(defVal, sqliteType);

    // 새 컬럼 객체 구성
    newCol.InitObject([
      'name',          colName,
      'type',          sqliteType,
      'original_type', mariaType,   // 원본 타입 보존
      'nullable',      isNullable and not isPK,
      'primary_key',   isPK,
      'autoincrement', isAutoInc,
      'default',       defVal,
      'comment',       comment
    ], JSON_OPTIONS_FAST);

    // UNIQUE 키 표시
    if SameTextU(colKey, 'UNI') then
      newCol.AddValue('unique', True);

    dstCols.AddItem(variant(newCol));
  end;

  // ── 3. indexes 배열 파싱 ──
  indexes := src.U['indexes'];
  srcIdxs.InitJson(indexes, JSON_OPTIONS_FAST);
  dstIdxs.InitArray([], JSON_OPTIONS_FAST);

  for i := 0 to srcIdxs.Count - 1 do
  begin
    idx.InitJson(VariantToUtf8(srcIdxs.Values[i]), JSON_OPTIONS_FAST);

    // PRIMARY KEY는 SQLite에서 테이블 정의에 포함되므로 스킵
    if SameTextU(idx.U['index_name'], 'PRIMARY') then
      Continue;

    // FULLTEXT / SPATIAL → SQLite 미지원이므로 스킵
    if SameTextU(idx.U['type'], 'FULLTEXT') or
       SameTextU(idx.U['type'], 'SPATIAL')  then
      Continue;

    newIdx.InitObject([
      'index_name', idx.U['index_name'],
      'unique',     not idx.B['non_unique'],
      'seq',        idx.I['seq'],
      'column',     idx.U['column'],
      'type',       'BTREE'   // SQLite는 BTREE만 지원
    ], JSON_OPTIONS_FAST);

    dstIdxs.AddItem(variant(newIdx));
  end;

  // ── 4. 결과 JSON 조립 ──
  dst.InitObject([
    'table',    tableName,
    'dialect',  'sqlite',
    'columns',  variant(dstCols),
    'indexes',  variant(dstIdxs)
  ], JSON_OPTIONS_FAST);

  Result := dst.ToJson;
end;

class function TMormot_MariaDB.GetTableStructureAsJson(
  aConnection: TSqlDBConnection; const aTableName: RawUtf8): RawUtf8;
var
  stmt    : ISqlDBStatement;
  writer  : TJsonWriter;
  temp    : TTextWriterStackBuffer;
  colName : RawUtf8;
  colType : RawUtf8;
  colNull : RawUtf8;
  colKey  : RawUtf8;
  colDef  : RawUtf8;
  colExtra: RawUtf8;
begin
  Result := '';

  // SQL injection 방어: 테이블명 검증
  if not IsValidIdentifier(aTableName) then
    raise ESqlDBException.CreateUtf8('Invalid table name: [%]', [aTableName]);

  writer := TJsonWriter.CreateOwnedStream(temp);
  try
    writer.Add('{');
    writer.AddFieldName('table');
    writer.AddString(aTableName);
    writer.AddComma;
    writer.AddFieldName('columns');
    writer.Add('[');

    // INFORMATION_SCHEMA 쿼리로 컬럼 정보 조회
    stmt := aConnection.NewStatementPrepared(
      'SELECT ' +
      '  COLUMN_NAME, ' +
      '  COLUMN_TYPE, ' +
      '  IS_NULLABLE, ' +
      '  COLUMN_KEY, ' +
      '  COLUMN_DEFAULT, ' +
      '  EXTRA, ' +
      '  CHARACTER_SET_NAME, ' +
      '  COLLATION_NAME, ' +
      '  COLUMN_COMMENT ' +
      'FROM INFORMATION_SCHEMA.COLUMNS ' +
      'WHERE TABLE_SCHEMA = DATABASE() ' +
      '  AND TABLE_NAME = ? ' +
      'ORDER BY ORDINAL_POSITION',
      True);  // True = ExpectResults

    stmt.BindTextS(1, aTableName);
    stmt.ExecutePrepared;

    writer.Add('[');
    while stmt.Step do
    begin
      writer.Add('{');

      writer.AddFieldName('name');
      writer.AddJsonString(stmt.ColumnUtf8(0));   // COLUMN_NAME
      writer.AddComma;

      writer.AddFieldName('type');
      writer.AddJsonString(stmt.ColumnUtf8(1));   // COLUMN_TYPE
      writer.AddComma;

      writer.AddFieldName('nullable');
      writer.Add(SameTextU(stmt.ColumnUtf8(2), 'YES'));  // IS_NULLABLE → bool
      writer.AddComma;

      writer.AddFieldName('key');
      writer.AddJsonString(stmt.ColumnUtf8(3));   // COLUMN_KEY (PRI/UNI/MUL)
      writer.AddComma;

      writer.AddFieldName('default');
      if stmt.ColumnNull(4) then
        writer.AddNull
      else
        writer.AddJsonString(stmt.ColumnUtf8(4)); // COLUMN_DEFAULT
      writer.AddComma;

      writer.AddFieldName('extra');
      writer.AddJsonString(stmt.ColumnUtf8(5));   // EXTRA (auto_increment 등)
      writer.AddComma;

      writer.AddFieldName('charset');
      if stmt.ColumnNull(6) then
        writer.AddNull
      else
        writer.AddJsonString(stmt.ColumnUtf8(6)); // CHARACTER_SET_NAME
      writer.AddComma;

      writer.AddFieldName('collation');
      if stmt.ColumnNull(7) then
        writer.AddNull
      else
        writer.AddJsonString(stmt.ColumnUtf8(7)); // COLLATION_NAME
      writer.AddComma;

      writer.AddFieldName('comment');
      writer.AddJsonString(stmt.ColumnUtf8(8));   // COLUMN_COMMENT

      writer.Add('}');
      writer.AddComma;
    end;

    writer.CancelLastComma;
    writer.Add(']');

    // 인덱스 정보도 함께 포함
    writer.AddComma;
    writer.AddFieldName('indexes');

    stmt := aConnection.NewStatementPrepared(
      'SELECT ' +
      '  INDEX_NAME, ' +
      '  NON_UNIQUE, ' +
      '  SEQ_IN_INDEX, ' +
      '  COLUMN_NAME, ' +
      '  INDEX_TYPE ' +
      'FROM INFORMATION_SCHEMA.STATISTICS ' +
      'WHERE TABLE_SCHEMA = DATABASE() ' +
      '  AND TABLE_NAME = ? ' +
      'ORDER BY INDEX_NAME, SEQ_IN_INDEX',
      True);

    stmt.BindTextS(1, aTableName);
    stmt.ExecutePrepared;

    writer.Add('[');
    while stmt.Step do
    begin
      writer.Add('{');
      writer.AddFieldName('index_name');
      writer.AddJsonString(stmt.ColumnUtf8(0));
      writer.AddComma;
      writer.AddFieldName('non_unique');
      writer.Add(stmt.ColumnInt(1) <> 0);
      writer.AddComma;
      writer.AddFieldName('seq');
      writer.Add(stmt.ColumnInt(2));
      writer.AddComma;
      writer.AddFieldName('column');
      writer.AddJsonString(stmt.ColumnUtf8(3));
      writer.AddComma;
      writer.AddFieldName('type');
      writer.AddJsonString(stmt.ColumnUtf8(4));
      writer.Add('}');
      writer.AddComma;
    end;

    writer.CancelLastComma;
    writer.Add(']');

    writer.Add('}');
    Result := writer.Text;

  finally
    writer.Free;
  end;
end;

class function TMormot_MariaDB.IsValidIdentifier(const aName: RawUtf8;
  aCheckReserved: Boolean): Boolean;
const
  // MariaDB 주요 예약어 목록 (대문자로 비교)
  MARIADB_RESERVED: array[0..78] of RawUtf8 = (
    'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'FROM', 'WHERE', 'TABLE',
    'CREATE', 'DROP', 'ALTER', 'INDEX', 'VIEW', 'DATABASE', 'SCHEMA',
    'GRANT', 'REVOKE', 'COMMIT', 'ROLLBACK', 'TRANSACTION', 'BEGIN',
    'JOIN', 'INNER', 'OUTER', 'LEFT', 'RIGHT', 'FULL', 'CROSS',
    'ON', 'AS', 'IN', 'IS', 'NOT', 'NULL', 'AND', 'OR', 'XOR',
    'LIKE', 'BETWEEN', 'EXISTS', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
    'ORDER', 'GROUP', 'BY', 'HAVING', 'LIMIT', 'OFFSET', 'UNION',
    'ALL', 'DISTINCT', 'INTO', 'SET', 'VALUES', 'DEFAULT',
    'PRIMARY', 'KEY', 'FOREIGN', 'REFERENCES', 'UNIQUE', 'CHECK',
    'CONSTRAINT', 'AUTO_INCREMENT', 'UNSIGNED', 'ZEROFILL',
    'INT', 'VARCHAR', 'TEXT', 'BLOB', 'DATE', 'DATETIME', 'TIMESTAMP',
    'FLOAT', 'DOUBLE', 'DECIMAL', 'BOOLEAN', 'ENUM'
  );
var
  i   : Integer;
  c   : AnsiChar;
  up  : RawUtf8;
begin
  Result := False;

  // 1. 빈 문자열 체크
  if aName = '' then
    Exit;

  // 2. 길이 체크 (MariaDB 최대 64자)
  if Length(aName) > 64 then
    Exit;

  // 3. 첫 글자: 숫자이면 안 됨
  c := aName[1];
  if c in ['0'..'9'] then
    Exit;

  // 4. 허용 문자 검사: A-Z, a-z, 0-9, _, $
  for i := 1 to Length(aName) do
  begin
    c := aName[i];
    if not (c in ['A'..'Z', 'a'..'z', '0'..'9', '_', '$']) then
      Exit;
  end;

  // 5. 예약어 검사 (옵션)
  if aCheckReserved then
  begin
    up := UpperCase(aName);
    for i := Low(MARIADB_RESERVED) to High(MARIADB_RESERVED) do
      if up = MARIADB_RESERVED[i] then
        Exit;
  end;

  Result := True;
end;

class function TMormot_MariaDB.MariaDbTypeToSQLite(
  const aMariaType: RawUtf8): RawUtf8;
var
  t: RawUtf8;
begin
  t := LowerCase(aMariaType);

  // 백틱/괄호 앞까지만 기본 타입 추출
  // 예: 'varchar(255)' → 'varchar', 'int(11) unsigned' → 'int'
  t := TrimU(Split(Split(t, '('), ' '));

  // ── INTEGER 계열 ──
  if t = 'tinyint'    then Exit('INTEGER');  // BOOLEAN 대용 포함
  if t = 'smallint'   then Exit('INTEGER');
  if t = 'mediumint'  then Exit('INTEGER');
  if t = 'int'        then Exit('INTEGER');
  if t = 'integer'    then Exit('INTEGER');
  if t = 'bigint'     then Exit('INTEGER');
  if t = 'bit'        then Exit('INTEGER');
  if t = 'bool'       then Exit('INTEGER');
  if t = 'boolean'    then Exit('INTEGER');
  if t = 'year'       then Exit('INTEGER');

  // ── REAL 계열 ──
  if t = 'float'      then Exit('REAL');
  if t = 'double'     then Exit('REAL');
  if t = 'real'       then Exit('REAL');

  // ── NUMERIC 계열 (정밀도 보존) ──
  if t = 'decimal'    then Exit('NUMERIC');
  if t = 'numeric'    then Exit('NUMERIC');
  if t = 'dec'        then Exit('NUMERIC');
  if t = 'fixed'      then Exit('NUMERIC');

  // ── TEXT 계열 ──
  if t = 'char'       then Exit('TEXT');
  if t = 'varchar'    then Exit('TEXT');
  if t = 'tinytext'   then Exit('TEXT');
  if t = 'text'       then Exit('TEXT');
  if t = 'mediumtext' then Exit('TEXT');
  if t = 'longtext'   then Exit('TEXT');
  if t = 'enum'       then Exit('TEXT');
  if t = 'set'        then Exit('TEXT');
  if t = 'json'       then Exit('TEXT');

  // ── 날짜/시간 → TEXT (SQLite 권장 방식) ──
  if t = 'date'       then Exit('TEXT');
  if t = 'datetime'   then Exit('TEXT');
  if t = 'timestamp'  then Exit('TEXT');
  if t = 'time'       then Exit('TEXT');

  // ── BLOB 계열 ──
  if t = 'tinyblob'   then Exit('BLOB');
  if t = 'blob'       then Exit('BLOB');
  if t = 'mediumblob' then Exit('BLOB');
  if t = 'longblob'   then Exit('BLOB');
  if t = 'binary'     then Exit('BLOB');
  if t = 'varbinary'  then Exit('BLOB');
  if t = 'geometry'   then Exit('BLOB');

  // 알 수 없는 타입은 TEXT로 폴백
  Result := 'TEXT';
end;

class function TMormot_MariaDB.MariaDB_AesDecrypt(const HexPass,
  PW: RawUtf8): RawUtf8;
var
  Aes: TAesEcb;
  RawEncrypted: RawByteString;
  AesKey: array[0..15] of Byte;
  i: Integer;
begin
  Result := '';
  if (HexPass = '') or (PW = '') then
    Exit;
  FillChar(AesKey, SizeOf(AesKey), 0);
  for i := 1 to Length(PW) do // 1-based string
    AesKey[(i - 1) mod 16] := AesKey[(i - 1) mod 16] xor Ord(PW[i]);
  // HexDecode 대신 mORMot 2 공식 함수인 HexToBin 사용
  RawEncrypted := HexToBin(HexPass);

  if RawEncrypted = '' then
    Exit;
  Aes := TAesEcb.Create(AesKey, 128);
  try
    Result := Aes.DecryptPkcs7(RawEncrypted, False, False);
  finally
    Aes.Free;
  end;
end;

class function TMormot_MariaDB.MariaDB_AesEncrypt(const PlainText,
  PW: RawUtf8): RawUtf8;
var
  Aes: TAesEcb;
  RawEncrypted: RawByteString;
  AesKey: array[0..15] of Byte; // 128 bit = 16 bytes
  i: Integer;
begin
  Result := '';
  if (PlainText = '') or (PW = '') then
    Exit;
  // 1. MariaDB/MySQL의 Key 생성 (복호화와 완벽히 동일한 로직 적용)
  // AES-128 규칙에 맞게 16바이트로 캐스팅 (초과분은 XOR, 미만분은 #0)
  FillChar(AesKey, SizeOf(AesKey), 0);
  for i := 1 to Length(PW) do
    AesKey[(i - 1) mod 16] := AesKey[(i - 1) mod 16] xor Ord(PW[i]);
  // 2. TAesEcb를 생성하여 암호화 (AES-128-ECB)
  Aes := TAesEcb.Create(AesKey, 128);
  try
    // EncryptPkcs7 함수를 통해 암호화 및 PKCS7 패딩이 자동으로 이루어집니다.
    // IV(초기화 벡터)는 적용 대상이 아니므로 False를 줍니다.
    RawEncrypted := Aes.EncryptPkcs7(PlainText, False, 0);
  finally
    Aes.Free;
  end;
  // 3. MySQL의 HEX() 함수처럼 바이너리 값을 형태의 Hex 대문자로 변환하여 반환
  // mORMot 2 버전에 따라 BinToHex 혹은 HexEncode 함수 등을 사용합니다.
  Result := BinToHex(RawEncrypted);
end;

end.
