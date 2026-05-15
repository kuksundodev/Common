unit UnitMormotDbConnectionPool;
{
var
  Props: TSqlDBConnectionProperties;
  Pool: TDbConnectionPool;
  Conn: TSqlDBConnection;
begin
  Props := TSqlDBSQLite3ConnectionProperties.Create('test.db', '', '', '');
  Pool := TDbConnectionPool.Create(Props, 20);

  Conn := Pool.Acquire;
  try
    Conn.Execute('SELECT * FROM my_table', true);
  finally
    Pool.Release(Conn);
  end;
end;
}

interface

uses
  SysUtils,
  Classes,
  SyncObjs,
  mormot.db.sql;

type
  TMormotDbConnectionPool = class
  private
    FProps: TSqlDBConnectionProperties;
    FPool: TList;
    FLock: TCriticalSection;
    FMaxPoolSize: Integer;
    FCurrentCount: Integer;

  public
    constructor Create(aProps: TSqlDBConnectionProperties; aMaxPoolSize: Integer = 10);
    destructor Destroy; override;

    function Acquire: TSqlDBConnection;
    procedure Release(aConn: TSqlDBConnection);
  end;

implementation

{ TMormotDbConnectionPool }

constructor TMormotDbConnectionPool.Create(aProps: TSqlDBConnectionProperties; aMaxPoolSize: Integer);
begin
  inherited Create;
  FProps := aProps;
  FMaxPoolSize := aMaxPoolSize;
  FPool := TList.Create;
  FLock := TCriticalSection.Create;
  FCurrentCount := 0;
end;

destructor TMormotDbConnectionPool.Destroy;
var
  i: Integer;
begin
  FLock.Acquire;
  try
    for i := 0 to FPool.Count - 1 do
      TSqlDBConnection(FPool[i]).Free;
    FPool.Free;
  finally
    FLock.Release;
    FLock.Free;
  end;
  inherited;
end;

function TMormotDbConnectionPool.Acquire: TSqlDBConnection;
begin
  FLock.Acquire;
  try
    // 풀에 남아있는 커넥션 사용
    if FPool.Count > 0 then
    begin
      Result := TSqlDBConnection(FPool.Last);
      FPool.Delete(FPool.Count - 1);
      Exit;
    end;

    // 새 커넥션 생성
    if FCurrentCount < FMaxPoolSize then
    begin
      Result := FProps.NewConnection;
      Result.Connect;
      Inc(FCurrentCount);
      Exit;
    end;
  finally
    FLock.Release;
  end;

  // 풀 꽉 찼을 때 (대기 전략 간단 구현)
  while True do
  begin
    Sleep(10);

    FLock.Acquire;
    try
      if FPool.Count > 0 then
      begin
        Result := TSqlDBConnection(FPool.Last);
        FPool.Delete(FPool.Count - 1);
        Exit;
      end;
    finally
      FLock.Release;
    end;
  end;
end;

procedure TMormotDbConnectionPool.Release(aConn: TSqlDBConnection);
begin
  if aConn = nil then
    Exit;

  FLock.Acquire;
  try
    FPool.Add(aConn);
  finally
    FLock.Release;
  end;
end;

end.
