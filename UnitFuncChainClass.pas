unit UnitFuncChainClass;
{
Chain1.Add(
  procedure(Context: TChainContext;
            const AText: string;
            AValue: Integer;
            Done: TChainDoneProc)
  begin
    Context.SetValue('Total', 100);
    Done(True);
  end);

Chain2.Add(
  procedure(Context: TChainContext;
            const AText: string;
            AValue: Integer;
            Done: TChainDoneProc)
  var
    Total: Integer;
  begin
    if Context.TryGetValue<Integer>('Total', Total) then
    begin
      ShowMessage('이전 결과: ' + Total.ToString);
      Context.SetValue('Final', Total + 50);
      Done(True);
    end
    else
      Done(False);
  end);

Chain3.Add(
  procedure(Context: TChainContext;
            const AText: string;
            AValue: Integer;
            Done: TChainDoneProc)
  var
    FinalValue: Integer;
  begin
    FinalValue := Context.GetValue<Integer>('Final');
    ShowMessage('최종 값: ' + FinalValue.ToString);
    Done(True);
  end);

-------------------------------------------
Chain1 → Context['Total']=100
Chain2 → Context['Final']=150
Chain3 → 150 출력
-------------------------------------------


}

interface

uses
  System.SysUtils, Classes, System.Rtti,
  System.Generics.Collections, Winapi.Windows;

type
  TFunctionChain = class;

  TChainContext = class
  private
    FValues: TDictionary<string, TValue>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetValue(const Key: string; const Value: TValue);
    function GetValue<T>(const Key: string): T;
    function TryGetValue<T>(const Key: string; out Value: T): Boolean;
    procedure Clear;
  end;
                                                         // 성공 여부 // True=성공, False=실패
  TChainDoneProc = procedure(Success: Boolean) of object;
  TChainProc = procedure(Context: TChainContext; const AText: string; AValue: Integer; ADone: TProc<Boolean>) of object;
  TFuncChainStepChanged = procedure(Chain: TFunctionChain; StepIndex: Integer; StepName: string) of object;

//  TChainProc = TProc<string, integer>;
  TChainProcWrapper = record
    Name: string;
    StrParam: string;
    IntParam: Integer;
    TimeOutMs: integer;
    Proc: TChainProc;
  end;

  TFunctionChain = class
  private
    FContext: TChainContext; //이전 Chain의 결과를 다음 Chain으로 전달할 때 사용됨
    FQueue: TQueue<TChainProcWrapper>;
    FRunning: Boolean;
    FCancelled   : Boolean;
    //True → 모든 단계 성공 후 정상 종료
    //False → 진행 중이거나 실패/취소
    FCompleted: Boolean;
    FTimeoutMs   : integer;
    FStepStart   : Cardinal;
    FCurrentText: string;
    FCurrentValue: Integer;

    FCurrentStep: Integer;
    FTotalSteps: Integer;
    FCurrentStepName: string;
    FNextPending: Boolean;   // Tick에서 다음 Step 실행
    FOnStepChanged: TFuncChainStepChanged;

    procedure ExecuteNext;
    procedure StepCompleted(Success: Boolean);
    procedure CheckTimeout;
  public
    constructor Create;
    destructor Destroy; override;

    function Count(): integer;
    procedure Clear;
    procedure Add(const Name: string; const AProc: TChainProc); overload;
    procedure Add(AProcRec: TChainProcWrapper); overload;
    procedure Start(const AText: string; AValue: Integer; ATimeoutMs: integer = 0); overload;// 첫 함수 자동 실행
    procedure Start(); overload;// 첫 함수 자동 실행
    procedure RequestNext(const AText: string; AValue: Integer);    // 외부에서 다음 실행 요청
    procedure Cancel;
    procedure Tick; // 타이머에서 호출
    function DequeChainProcWrapper(): TChainProcWrapper;

    property IsRunning: Boolean read FRunning;
    property IsCompleted: Boolean read FCompleted; // 외부 확인용

    property CurrentStep: Integer read FCurrentStep;
    property TotalSteps: Integer read FTotalSteps;
    property CurrentStepName: string read FCurrentStepName;
    property OnStepChanged: TFuncChainStepChanged read FOnStepChanged;
  end;

type
  TChainItem = class
  public
    Chain: TFunctionChain;
    RetryCount: Integer;
    MaxRetry: Integer;

    destructor Destroy; override;
  end;

  TChainFailedEvent = procedure(AChain: TFunctionChain) of object;

  TChainSequenceManager = class
  private
    FChains: TObjectList<TChainItem>;
    FFailedChains: TList<TFunctionChain>;
    FCurrentIndex: Integer;
    FRunning: Boolean;
    FCompleted: Boolean;
    FOnChainFailed: TChainFailedEvent;

    procedure StartNextChain;
    procedure HandleFailure(Item: TChainItem);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    function Count(): integer;
    procedure AddChain(AChain: TFunctionChain; MaxRetry: Integer = 0);
    procedure Start;
    procedure Tick;
    procedure Cancel(const AIsCancelCurrent: Boolean=False);
    function GetStepInfo(AIndex: integer = -1): string;
    function GetChainItemByIndex(AIndex: integer = -1): TChainItem;

    property IsRunning: Boolean read FRunning;
    property IsCompleted: Boolean read FCompleted;
    property FailedChains: TList<TFunctionChain> read FFailedChains;
    property OnChainFailed: TChainFailedEvent read FOnChainFailed write FOnChainFailed;
  end;
implementation

procedure TFunctionChain.Add(AProcRec: TChainProcWrapper);
var
  LRec: TChainProcWrapper;
begin
  LRec := AProcRec;

  FQueue.Enqueue(LRec);

  Inc(FTotalSteps);
end;

procedure TFunctionChain.Cancel;
begin
  FCancelled := True;
  FRunning := False;
  FCompleted := False;
  FNextPending := False;
  FQueue.Clear;

  if Assigned(FContext) then
    FContext.Clear;
end;

procedure TFunctionChain.CheckTimeout;
begin
  if not FRunning then Exit;
  if FTimeoutMs = 0 then Exit;
  if GetTickCount - FStepStart > FTimeoutMs then
  begin
    Cancel;
  end;
end;

procedure TFunctionChain.Clear;
begin
  FQueue.Clear;
end;

function TFunctionChain.Count: integer;
begin
  Result := FQueue.Count;
end;

constructor TFunctionChain.Create;
begin
  FQueue := TQueue<TChainProcWrapper>.Create;
  FContext := TChainContext.Create;
end;

function TFunctionChain.DequeChainProcWrapper: TChainProcWrapper;
begin
  Result := FQueue.Dequeue;
end;

destructor TFunctionChain.Destroy;
begin
  FQueue.Free;
  FContext.Free;
  inherited;
end;

procedure TFunctionChain.Add(const Name: string; const AProc: TChainProc);
var
  LRec: TChainProcWrapper;
begin
  LRec.Name := Name;
  LRec.Proc := AProc;

  FQueue.Enqueue(LRec);

  Inc(FTotalSteps);
end;

procedure TFunctionChain.Start(const AText: string; AValue: Integer; ATimeoutMs: integer);
begin
  if not FRunning then
  begin
    FCancelled := False;
    FCompleted := False;  // 시작 시 초기화
    FCurrentText := AText;
    FCurrentValue := AValue;
    FTimeoutMs := ATimeoutMs;

    ExecuteNext;
  end;
end;

procedure TFunctionChain.Start;
begin
  Start('', -1, -1)
end;

procedure TFunctionChain.StepCompleted(Success: Boolean);
begin
  TThread.Queue(nil,
    procedure
    begin
      if FCancelled then
      begin
        FRunning := False;
        FCompleted := False;
        Exit;
      end;
      if not Success then
      begin
        FRunning := False;
        FCompleted := False;
        Exit;
      end;

      // 다음 Step 실행 예약
      FNextPending := True;

//      ExecuteNext;
    end);
end;

procedure TFunctionChain.Tick;
begin
  if not FRunning then Exit;

//  CheckTimeout;

  if FNextPending then
  begin
    FNextPending := False;
    ExecuteNext;
  end;
end;

procedure TFunctionChain.RequestNext(const AText: string; AValue: Integer);
begin
  // 실행 중이면 무시
  if FRunning then
    Exit;

  FCurrentText := AText;
  FCurrentValue := AValue;
  ExecuteNext;
end;

procedure TFunctionChain.ExecuteNext;
var
  ProcRec: TChainProcWrapper;
begin
  if FCancelled then
  begin
    FRunning := False;
    Exit;
  end;

  if FQueue.Count = 0 then
  begin
    FRunning := False;
    FCompleted := True;   // 모든 단계 성공
    Exit;
  end;

  FRunning := True;
  FStepStart := GetTickCount;

  ProcRec := FQueue.Dequeue;

  Inc(FCurrentStep);
  FCurrentStepName := ProcRec.Name;

  if FCurrentText = '' then
    FCurrentText := ProcRec.StrParam;

  if FCurrentValue = -1 then
    FCurrentValue := ProcRec.IntParam;

  if FTimeoutMs = -1 then
    FTimeoutMs := ProcRec.TimeOutMs;

  try
    ProcRec.Proc(FContext, FCurrentText, FCurrentValue, StepCompleted);
  finally
    FNextPending := True; // 다음 Step 실행 예약

    if Assigned(FOnStepChanged) then
      FOnStepChanged(Self, FCurrentStep, FCurrentStepName);
  end;
end;

{ TChainSequenceManager }

procedure TChainSequenceManager.Cancel(const AIsCancelCurrent: Boolean);
var
  Item: TChainItem;
begin
  if not FRunning then
    Exit;

  // 현재 실행 중인 체인 Cancel
  if (FCurrentIndex >= 0) and (FCurrentIndex < FChains.Count) then
    FChains[FCurrentIndex].Chain.Cancel;

  if AIsCancelCurrent then
    exit;

  // Manager 상태 정지
  FRunning := False;
  FCompleted := False;

  // 필요하면 모든 체인도 Cancel
  for Item in FChains do
    Item.Chain.Cancel;
end;

procedure TChainSequenceManager.Clear;
var
  Item: TChainItem;
begin
  // 실행 중지
  FRunning := False;
  FCompleted := False;
  FCurrentIndex := 0;
  // 실패 목록 초기화
  FFailedChains.Clear;
  // 체인 내부 상태 초기화
  for Item in FChains do
  begin
    if Assigned(Item.Chain) then
      Item.Chain.Clear;   // TFunccChain.Clear
  end;
  // 체인 목록 제거
  FChains.Clear;
end;

function TChainSequenceManager.Count: integer;
begin
  Result := FChains.Count;
end;

constructor TChainSequenceManager.Create;
begin
  FChains := TObjectList<TChainItem>.Create(True);
  FFailedChains := TList<TFunctionChain>.Create;
end;

destructor TChainSequenceManager.Destroy;
begin
  FChains.Clear;
  FChains.Free;
  FFailedChains.Free;
  inherited;
end;

function TChainSequenceManager.GetChainItemByIndex(AIndex: integer): TChainItem;
var
  Item: TChainItem;
begin
  Result := nil;
  if AIndex = -1 then
    AIndex := FCurrentIndex;
  if AIndex >= FChains.Count then
    Exit;
  Result := FChains[AIndex];
end;

function TChainSequenceManager.GetStepInfo(AIndex: integer): string;
var
  Item: TChainItem;
begin
  if AIndex = -1 then
    AIndex := FCurrentIndex;
  Item := GetChainItemByIndex(AIndex);
  Result :=
    Format('Chain %d | Step %d/%d | %s',
    [
      AIndex + 1,
      Item.Chain.CurrentStep,
      Item.Chain.TotalSteps,
      Item.Chain.CurrentStepName
    ]);
end;

procedure TChainSequenceManager.AddChain(AChain: TFunctionChain; MaxRetry: Integer);
var
  Item: TChainItem;
begin
  Item := TChainItem.Create;
  Item.Chain := AChain;
  Item.MaxRetry := MaxRetry;
  Item.RetryCount := 0;

  FChains.Add(Item);
end;

procedure TChainSequenceManager.Start;
begin
  if FRunning then Exit;

  FCurrentIndex := 0;
  FCompleted := False;
  FRunning := True;
  FFailedChains.Clear;

  StartNextChain;
end;

procedure TChainSequenceManager.StartNextChain;
begin
  if FCurrentIndex >= FChains.Count then
  begin
    FRunning := False;
    FCompleted := True;
    Exit;
  end;

  FChains[FCurrentIndex].Chain.Start('', -1, -1);
end;

procedure TChainSequenceManager.HandleFailure(Item: TChainItem);
begin
  Inc(Item.RetryCount);

  if Item.RetryCount <= Item.MaxRetry then
  begin
    // Retry 실행
    Item.Chain.Start('', 0);
  end
  else
  begin
    // 최종 실패 → 기록
    FFailedChains.Add(Item.Chain);

    if Assigned(FOnChainFailed) then
      FOnChainFailed(Item.Chain);

    Inc(FCurrentIndex);
    StartNextChain;
  end;
end;

procedure TChainSequenceManager.Tick;
var
  Item: TChainItem;
begin
  if not FRunning then Exit;
  if FCurrentIndex >= FChains.Count then Exit;

  Item := FChains[FCurrentIndex];

  Item.Chain.Tick;

  if not Item.Chain.IsRunning then
  begin
    if Item.Chain.IsCompleted then
    begin
      Inc(FCurrentIndex);
      StartNextChain;
    end
    else
    begin
      HandleFailure(Item);
    end;
  end;
end;

{ TChainContext }

procedure TChainContext.Clear;
begin
  FValues.Clear;
end;

constructor TChainContext.Create;
begin
  FValues := TDictionary<string, TValue>.Create;
end;

destructor TChainContext.Destroy;
begin
  FValues.Free;
  inherited;
end;

procedure TChainContext.SetValue(const Key: string; const Value: TValue);
begin
  FValues.AddOrSetValue(Key, Value);
end;

function TChainContext.GetValue<T>(const Key: string): T;
begin
  Result := FValues[Key].AsType<T>;
end;

function TChainContext.TryGetValue<T>(const Key: string; out Value: T): Boolean;
var
  V: TValue;
begin
  Result := FValues.TryGetValue(Key, V);
  if Result then
    Value := V.AsType<T>;
end;

{ TChainItem }

destructor TChainItem.Destroy;
begin
  Chain.Free;

  inherited;
end;

end.
