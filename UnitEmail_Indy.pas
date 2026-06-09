unit UnitEmail_Indy;
{
procedure TForm1.btnSendClick(Sender: TObject);
var
  Config : TMailConfig;
  Sender : TMailSender;
  Ret    : Integer;
begin
  Config.SMTPHost    := 'smtp.gmail.com';
  Config.SMTPPort    := 587;
  Config.UseSSL      := False;
  Config.UseTLS      := True;
  Config.UserID      := 'yourID@gmail.com';
  Config.Password    := 'yourPassword';
  Config.FromEmail   := 'yourID@gmail.com';
  Config.FromName    := '발신자 이름';
  Config.Subject     := '파일 전송';
  Config.Body        := '첨부 파일을 확인하세요.';
  Config.LogFilePath := 'C:\Logs\mail_log.txt';
  Config.LogMemo     := Memo1;  // 폼의 TMemo 컴포넌트

  Sender := TMailSender.Create(Config);
  try
    Ret := Sender.SendMail('receiver@example.com', 'C:\Files\report.xlsx');
    case Ret of
      0  : ShowMessage('전송 성공');
      1  : ShowMessage('파일을 찾을 수 없음');
      2  : ShowMessage('ZIP 압축 실패');
      3  : ShowMessage('서버 연결 실패');
      4  : ShowMessage('인증 실패');
      5  : ShowMessage('전송 실패');
      6  : ShowMessage('전송 취소됨');
      else ShowMessage('알 수 없는 오류');
    end;
  finally
    Sender.Free;
  end;
end;

// 전송 중단 버튼
procedure TForm1.btnCancelClick(Sender: TObject);
begin
  if Assigned(MailSender) then
    MailSender.Cancel;
end;
}

interface

uses
  System.SysUtils, System.Classes, System.Zip,
  IdSMTP, IdMessage, IdAttachmentFile, IdSSLOpenSSL,
  IdExplicitTLSClientCustom, IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdMessageParts,
  Vcl.StdCtrls, Vcl.Forms;

type
  // 전송 상태 코드
  TMailResult = (
    mrSuccess        = 0,  // 성공
    mrFileNotFound   = 1,  // 파일 없음
    mrZipFailed      = 2,  // 압축 실패
    mrConnectFailed  = 3,  // 서버 연결 실패
    mrAuthFailed     = 4,  // 인증 실패
    mrSendFailed     = 5,  // 전송 실패
    mrCancelled      = 6,  // 사용자 취소
    mrUnknownError   = 99  // 알 수 없는 오류
  );

  TMailConfig = record
    SMTPHost     : string;   // SMTP 서버 주소
    SMTPPort     : Integer;  // SMTP 포트 (보통 587 or 465)
    UseSSL       : Boolean;  // SSL 사용 여부
    UseTLS       : Boolean;  // TLS 사용 여부
    UserID       : string;   // 로그인 ID
    Password     : string;   // 로그인 PW
    FromEmail    : string;   // 발신자 이메일
    FromName     : string;   // 발신자 이름
    Subject      : string;   // 메일 제목
    Body         : string;   // 메일 본문
    LogFilePath  : string;   // 로그 파일 경로
    LogMemo      : TMemo;    // 로그 출력 메모 컴포넌트 (nil 가능)
  end;

  TMailSender = class
  private
    FCancelled  : Boolean;
    FConfig     : TMailConfig;

    procedure WriteLog(const AMsg: string);
    function  CompressFile(const ASrcFile, AZipFile: string): Boolean;
  public
    constructor Create(const AConfig: TMailConfig);

    procedure Cancel;

    function SendMail(
      const AToEmail : string;
      const AFileName: string
    ): Integer;
  end;

implementation

{ TMailSender }

constructor TMailSender.Create(const AConfig: TMailConfig);
begin
  inherited Create;
  FConfig    := AConfig;
  FCancelled := False;
end;

procedure TMailSender.Cancel;
begin
  FCancelled := True;
end;

// ── 로그 기록 ──────────────────────────────────────────────────────────────
procedure TMailSender.WriteLog(const AMsg: string);
var
  LogLine : string;
  F       : TextFile;
begin
  LogLine := Format('[%s] %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), AMsg]);

  // 메모 컴포넌트 출력
  if Assigned(FConfig.LogMemo) then
  begin
    FConfig.LogMemo.Lines.Add(LogLine);
    Application.ProcessMessages; // UI 갱신
  end;

  // 로그 파일 기록
  if FConfig.LogFilePath <> '' then
  begin
    AssignFile(F, FConfig.LogFilePath);
    try
      if FileExists(FConfig.LogFilePath) then
        Append(F)
      else
        Rewrite(F);
      Writeln(F, LogLine);
    finally
      CloseFile(F);
    end;
  end;
end;

// ── ZIP 압축 ───────────────────────────────────────────────────────────────
function TMailSender.CompressFile(const ASrcFile, AZipFile: string): Boolean;
var
  Zip: TZipFile;
begin
  Result := False;
  try
    Zip := TZipFile.Create;
    try
      Zip.Open(AZipFile, zmWrite);
      Zip.Add(ASrcFile, ExtractFileName(ASrcFile));
      Zip.Close;
      Result := True;
    finally
      Zip.Free;
    end;
  except
    on E: Exception do
      WriteLog('ZIP 압축 오류: ' + E.Message);
  end;
end;

// ── 메인 전송 함수 ─────────────────────────────────────────────────────────
function TMailSender.SendMail(
  const AToEmail : string;
  const AFileName: string
): Integer;
var
  SMTP       : TIdSMTP;
  SSLHandler : TIdSSLIOHandlerSocketOpenSSL;
  Msg        : TIdMessage;
  Attachment : TIdAttachmentFile;
  ZipFile    : string;
begin
  Result     := Integer(mrUnknownError);
  FCancelled := False;
  ZipFile    := ChangeFileExt(AFileName, '.zip');

  WriteLog('==============================');
  WriteLog('전송 시작');
  WriteLog('수신자  : ' + AToEmail);
  WriteLog('파일    : ' + AFileName);

  // ── 1. 취소 확인 ──────────────────────────────────────────
  if FCancelled then
  begin
    WriteLog('전송 취소됨 (시작 전)');
    Exit(Integer(mrCancelled));
  end;

  // ── 2. 원본 파일 존재 확인 ─────────────────────────────────
  if not FileExists(AFileName) then
  begin
    WriteLog('오류: 파일을 찾을 수 없음 - ' + AFileName);
    Exit(Integer(mrFileNotFound));
  end;

  // ── 3. ZIP 압축 ────────────────────────────────────────────
  WriteLog('ZIP 압축 중...');
  if not CompressFile(AFileName, ZipFile) then
  begin
    WriteLog('오류: ZIP 압축 실패');
    Exit(Integer(mrZipFailed));
  end;
  WriteLog('ZIP 압축 완료: ' + ZipFile);

  // ── 4. 취소 재확인 ─────────────────────────────────────────
  if FCancelled then
  begin
    WriteLog('전송 취소됨 (압축 후)');
    if FileExists(ZipFile) then DeleteFile(ZipFile);
    Exit(Integer(mrCancelled));
  end;

  // ── 5. SMTP / 메시지 객체 생성 ────────────────────────────
  SMTP       := TIdSMTP.Create(nil);
  SSLHandler := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  Msg        := TIdMessage.Create(nil);
  try
    try
      // SSL/TLS 설정
      SSLHandler.SSLOptions.Method  := sslvTLSv1_2;
      SSLHandler.SSLOptions.Mode    := sslmClient;

      if FConfig.UseSSL then
      begin
        SMTP.IOHandler    := SSLHandler;
        SMTP.UseTLS       := utUseImplicitTLS;
      end
      else if FConfig.UseTLS then
      begin
        SMTP.IOHandler    := SSLHandler;
        SMTP.UseTLS       := utUseExplicitTLS;
      end;

      // SMTP 서버 연결 정보
      SMTP.Host     := FConfig.SMTPHost;
      SMTP.Port     := FConfig.SMTPPort;
      SMTP.Username := FConfig.UserID;
      SMTP.Password := FConfig.Password;
      SMTP.AuthType := satDefault;

      // 메시지 구성
      Msg.From.Address  := FConfig.FromEmail;
      Msg.From.Name     := FConfig.FromName;
      Msg.Recipients.EMailAddresses := AToEmail;
      Msg.Subject       := FConfig.Subject;
      Msg.Body.Text     := FConfig.Body;
      Msg.ContentType   := 'multipart/mixed';

      // ZIP 파일 첨부
      Attachment := TIdAttachmentFile.Create(Msg.MessageParts, ZipFile);
      Attachment.FileName := ExtractFileName(ZipFile);

      // ── 6. 취소 재확인 ───────────────────────────────────
      if FCancelled then
      begin
        WriteLog('전송 취소됨 (연결 전)');
        Result := Integer(mrCancelled);
        Exit;
      end;

      // ── 7. 서버 연결 ─────────────────────────────────────
      WriteLog('SMTP 서버 연결 중: ' + FConfig.SMTPHost);
      try
        SMTP.Connect;
      except
        on E: Exception do
        begin
          WriteLog('오류: 서버 연결 실패 - ' + E.Message);
          Result := Integer(mrConnectFailed);
          Exit;
        end;
      end;
      WriteLog('서버 연결 성공');

      // ── 8. 취소 재확인 (연결 후) ─────────────────────────
      if FCancelled then
      begin
        WriteLog('전송 취소됨 (연결 후)');
        SMTP.Disconnect;
        Result := Integer(mrCancelled);
        Exit;
      end;

      // ── 9. 메일 전송 ──────────────────────────────────────
      WriteLog('메일 전송 중...');
      try
        SMTP.Send(Msg);
        Result := Integer(mrSuccess);
        WriteLog('메일 전송 성공');
      except
        on E: EIdSMTPReplyError do
        begin
          WriteLog('오류: 인증 실패 - ' + E.Message);
          Result := Integer(mrAuthFailed);
        end;
        on E: Exception do
        begin
          WriteLog('오류: 전송 실패 - ' + E.Message);
          Result := Integer(mrSendFailed);
        end;
      end;

      if SMTP.Connected then
        SMTP.Disconnect;

    except
      on E: Exception do
      begin
        WriteLog('알 수 없는 오류: ' + E.Message);
        Result := Integer(mrUnknownError);
      end;
    end;
  finally
    Msg.Free;
    SSLHandler.Free;
    SMTP.Free;

    // 임시 ZIP 파일 삭제
    if FileExists(ZipFile) then
    begin
      DeleteFile(ZipFile);
      WriteLog('임시 ZIP 파일 삭제: ' + ZipFile);
    end;

    WriteLog(Format('전송 종료 (결과 코드: %d)', [Result]));
    WriteLog('==============================');
  end;
end;

end.
