unit UnitConsoleUtil;

interface

uses
  System.SysUtils,
  Winapi.Windows;

implementation

var
  GRunning: Boolean = True;

// 콘솔 이벤트 핸들러 (Ctrl+C, Ctrl+Break 등 처리)
function ConsoleCtrlHandler(CtrlType: DWORD): BOOL; stdcall;
begin
  Result := False;
  case CtrlType of
    CTRL_C_EVENT,
    CTRL_BREAK_EVENT,
    CTRL_CLOSE_EVENT:
      begin
        GRunning := False;
        Result := True;
      end;
  end;
end;

// 키 입력 감지 (논블로킹)
function CheckKeyPress: Char;
var
  InputRecord: TInputRecord;
  NumRead: DWORD;
  hInput: THandle;
begin
  Result := #0;
  hInput := GetStdHandle(STD_INPUT_HANDLE);

  // 입력 버퍼에 데이터가 있는지 확인 (블로킹 없이)
  if GetNumberOfConsoleInputEvents(hInput, NumRead) and (NumRead > 0) then
  begin
    ReadConsoleInput(hInput, InputRecord, 1, NumRead);
    if (InputRecord.EventType = KEY_EVENT) and
       (InputRecord.Event.KeyEvent.bKeyDown) then
    begin
      // Ctrl+X 감지: VkCode = X(0x58), Ctrl 키 상태 확인
      if (InputRecord.Event.KeyEvent.wVirtualKeyCode = $58) and  // 'X' key
         (InputRecord.Event.KeyEvent.dwControlKeyState and
          (LEFT_CTRL_PRESSED or RIGHT_CTRL_PRESSED) <> 0) then
        Result := ^X  // Ctrl+X = ASCII 24
      else
        Result := InputRecord.Event.KeyEvent.AsciiChar;
    end;
  end;
end;

procedure Run;
var
  Count: Integer;
  Key: Char;
begin
  // Ctrl+C 핸들러 등록
  SetConsoleCtrlHandler(@ConsoleCtrlHandler, True);

  WriteLn('=================================');
  WriteLn(' 실행 중... Ctrl+X 를 누르면 종료');
  WriteLn('=================================');

  Count := 0;

  while GRunning do
  begin
    // 작업 수행 (예시: 카운트 출력)
    Inc(Count);
    WriteLn(Format('[%d] 작업 중... ', [Count]));

    // Ctrl+X 키 감지
    Key := CheckKeyPress;
    if Key = ^X then  // ^X = Ctrl+X
    begin
      WriteLn('>>> Ctrl+X 감지 → 종료합니다.');
      GRunning := False;
      Break;
    end;

    Sleep(1000);  // 1초 대기
  end;
end;

end.
