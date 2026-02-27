unit UnitLogUtil;

interface

uses System.Classes, System.Sysutils, Vcl.StdCtrls, Forms;

procedure DoLogTextFile(const AFileName, ATxt: string);
procedure DoLogTFileStream(const AFileName, ATxt: string);
procedure DoLogMemo(const AMsg: string; AMemo: TMemo=nil);
procedure File_AddLog(sMessage: String; const IsClear: Boolean = True; IsMake: Boolean = False);
function DoDebug(AText: String): Boolean;

implementation

const
  MEMO_LOG_MAX_LINE_COUNT = 1000;

procedure DoLogTextFile(const AFileName, ATxt: string);
var
  F: TextFile;
begin
  AssignFile(F, AFileName);
  try
    if FileExists(AFileName) then
      Append(f)
    else
      Rewrite(f);
    WriteLn(f,ATxt);
  finally
    CloseFile(F);
  end;
end;

procedure DoLogTFileStream(const AFileName, ATxt: string);
var
  F: TFileStream;
  b: TBytes;
begin
  if FileExists(AFileName) then
    F := TFileStream.Create(AFileName, fmOpenReadWrite)
  else
    F := TFileStream.Create(AFileName, fmCreate);
  try
    F.Seek(0, soFromEnd);
    b := TEncoding.Default.GetBytes(ATxt + sLineBreak);
    F.Write(b, Length(b));
  finally
    F.Free;
  end;
end;

procedure DoLogMemo(const AMsg: string; AMemo: TMemo=nil);
begin
  if AMemo.Lines.Count > MEMO_LOG_MAX_LINE_COUNT then
    AMemo.Lines.Clear;

  AMemo.Lines.Add(AMsg);
end;

procedure File_AddLog(sMessage: String; const IsClear: Boolean; IsMake: Boolean);
begin
  if IsClear then begin
    sMessage := StringReplace(sMessage, #$0D + #$0A, ' ', [rfReplaceAll, rfIgnoreCase]);
    sMessage := StringReplace(sMessage, #$0D  , ' ', [rfReplaceAll, rfIgnoreCase]);
  end;

  if not DoDebug(sMessage) then begin
    Sleep(100);
    DoDebug(sMessage);
  end;
end;

function DoDebug(AText: String): Boolean;
var
  fFileName, Dir: String;
  fFile    : TextFile;

begin
  fFileName := Format('%s\log\%s.log', [ExtractFileDir(Application.ExeName),
                                        FormatDateTime('YYYYMMDD', Now)]);
  Dir := ExtractFilePath(fFileName);

  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);   // 중간 경로까지 모두 생성

  try
    AssignFile(fFile, fFileName);
    FileMode := fmOpenReadWrite or fmShareDenyWrite;

    {$I-}
    if FileExists(fFileName) then
      Append(fFile)
    else ReWrite(fFile);
    {$I+}

    WriteLn(fFile, Format('[%s]  %s', [FormatDateTime('HH:NN:SSS', Now), AText]));
    CloseFile(fFile);

    Result := True;
  except
    Result := False;
  end;
end;

end.
