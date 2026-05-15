unit UnitUniConnectionPool;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs, Data.DB, DBAccess,
  Uni, SQLServerUniProvider;

type
  TUniConnectionPool = class
  private
    FPool: TQueue<TUniConnection>;
    FLock: TCriticalSection;
    FMaxSize: Integer;
    FConnectionString,
    FProviderName: string;

    function CreateConnection: TUniConnection;
  public
    constructor Create(const AConnectionString: string; APoolSize: Integer);
    destructor Destroy; override;

    function Acquire: TUniConnection;
    procedure Release(AConn: TUniConnection);
  end;

implementation

{ TUniConnectionPool }

function TUniConnectionPool.Acquire: TUniConnection;
begin
  FLock.Enter;
  try
    if FPool.Count > 0 then
      Result := FPool.Dequeue
    else
      Result := CreateConnection; // 부족 시 추가 생성
  finally
    FLock.Leave;
  end;
end;

constructor TUniConnectionPool.Create(const AConnectionString: string;
  APoolSize: Integer);
var
  I: Integer;
begin
  FConnectionString := AConnectionString;
  FMaxSize := APoolSize;

  FPool := TQueue<TUniConnection>.Create;
  FLock := TCriticalSection.Create;

  for I := 1 to FMaxSize do
    FPool.Enqueue(CreateConnection);
end;

function TUniConnectionPool.CreateConnection: TUniConnection;
begin
  Result := TUniConnection.Create(nil);

//  Result.ProviderName := 'SQL Server';
//  Result.Database := 'CM_Master_Test3';
//  Result.Server   := '182.162.141.186,3436';
//  Result.Port     := 3436;
//  Result.Username := 'sa';
//  Result.Password := '!moonsy9124!';
  Result.ConnectString := FConnectionString;
  Result.LoginPrompt := False;

  Result.Connect;
end;

destructor TUniConnectionPool.Destroy;
var
  Conn: TUniConnection;
begin
  while FPool.Count > 0 do
  begin
    Conn := FPool.Dequeue;
    Conn.Free;
  end;

  FPool.Free;
  FLock.Free;

  inherited;
end;

procedure TUniConnectionPool.Release(AConn: TUniConnection);
begin
  if AConn = nil then
    Exit;

  FLock.Enter;
  try
    if not AConn.Connected then
    begin
      AConn.Free;
      Exit;
    end;

    if FPool.Count < FMaxSize then
      FPool.Enqueue(AConn)
    else
      AConn.Free;
  finally
    FLock.Leave;
  end;
end;

end.
