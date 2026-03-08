unit UnitCoroutineUtil;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs;

type
  TYieldInstruction = class
  public
    function KeepWaiting: Boolean; virtual; abstract;
  end;

  TWaitUntil = class(TYieldInstruction)
  private
    FPredicate: TFunc<Boolean>;
  public
    constructor Create(const APredicate: TFunc<Boolean>);
    function KeepWaiting: Boolean; override;
  end;

  TWaitWhile = class(TYieldInstruction)
  private
    FPredicate: TFunc<Boolean>;
  public
    constructor Create(const APredicate: TFunc<Boolean>);
    function KeepWaiting: Boolean; override;
  end;

  TWaitForEvent = class(TYieldInstruction)
  private
    FEvent: TEvent;
  public
    constructor Create(AEvent: TEvent);
    function KeepWaiting: Boolean; override;
  end;

  TCoroutineBase = class
  private
    FState: Integer;
    FFinished: Boolean;
    FCurrentYield: TYieldInstruction;
  protected
    procedure Yield(Instruction: TYieldInstruction);
    procedure Execute; virtual; abstract;
  public
    procedure Resume;

    property Finished: Boolean read FFinished write FFinished;
    property State: Integer read FState;
  end;

  TCoroutineScheduler = class
  private
    FList: TList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(C: TCoroutineBase);
    procedure Tick;
  end;

implementation

procedure TCoroutineBase.Yield(Instruction: TYieldInstruction);
begin
  FCurrentYield := Instruction;
  Inc(FState);
end;

procedure TCoroutineBase.Resume;
begin
  if FFinished then
    Exit;

  if Assigned(FCurrentYield) then
  begin
    if FCurrentYield.KeepWaiting then
      Exit
    else
      FCurrentYield := nil;
  end;

  Execute;
end;

{ TCoroutineScheduler }

constructor TCoroutineScheduler.Create;
begin
  FList := TList.Create;
end;
destructor TCoroutineScheduler.Destroy;
begin
  FList.Free;
  inherited;
end;
procedure TCoroutineScheduler.Add(C: TCoroutineBase);
begin
  FList.Add(C);
end;
procedure TCoroutineScheduler.Tick;
var
  I: Integer;
  C: TCoroutineBase;
begin
  for I := FList.Count - 1 downto 0 do
  begin
    C := TCoroutineBase(FList[I]);
    C.Resume;
    if C.Finished then
    begin
      FList.Delete(I);
      C.Free;
    end;
  end;
end;

{ TWaitUntil }

constructor TWaitUntil.Create(const APredicate: TFunc<Boolean>);
begin
  FPredicate := APredicate;
end;
function TWaitUntil.KeepWaiting: Boolean;
begin
  Result := not FPredicate();
end;

{ TWaitWhile }

constructor TWaitWhile.Create(const APredicate: TFunc<Boolean>);
begin

end;

function TWaitWhile.KeepWaiting: Boolean;
begin
  Result := FPredicate();
end;

{ TWaitForEvent }

constructor TWaitForEvent.Create(AEvent: TEvent);
begin
  FEvent := AEvent;
end;
function TWaitForEvent.KeepWaiting: Boolean;
begin
  Result := FEvent.WaitFor(0) <> wrSignaled;
end;

end.
