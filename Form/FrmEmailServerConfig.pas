unit FrmEmailServerConfig;

interface

uses
  Winapi.Windows, System.SysUtils, Vcl.Forms, Vcl.Controls, System.JSON,
  System.IOUtils,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs, System.Classes,
  IdSMTP, IdIMAP4, IdSSLOpenSSL, IdExplicitTLSClientServerBase;

// -------------------------------------------------------
//  이메일 서버 설정 Record 타입 정의
// -------------------------------------------------------
type
  frmEmailServerConfigRec = record
    // 발신 (SMTP)
    SmtpHost : string;
    SmtpPort : Integer;
    SmtpID   : string;
    SmtpPW   : string;
    // 수신 (POP3/IMAP)
    RecvHost : string;
    RecvPort : Integer;

    // 초기화 헬퍼
    procedure Clear;
  end;

  TEmailServerConfigF = class(TForm)
    gbSMTP:     TGroupBox;
    lblSmtpHost: TLabel;   edtSmtpHost: TEdit;
    lblSmtpPort: TLabel;   edtSmtpPort: TEdit;
    lblSmtpID:  TLabel;    edtSmtpID:  TEdit;
    lblSmtpPW:  TLabel;    edtSmtpPW:  TEdit;
    gbRecv:     TGroupBox;
    lblRecvHost: TLabel;   edtRecvHost: TEdit;
    lblRecvPort: TLabel;   edtRecvPort: TEdit;
    btnSave:  TButton;
    btnTest:  TButton;
    btnClose: TButton;
    procedure btnSaveClick(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
  private
    FConfig : frmEmailServerConfigRec;   // 내부 보관용 Record 변수

    function Validate: Boolean;

    function TestEmailServerConnection(out AMessage: string): Boolean;
  public
    FConfigJson: string;

    procedure SaveConfigToJson();
    procedure LoadConfigFromJson(const AJson: string);

    procedure SaveToRecord  (out AConfig : frmEmailServerConfigRec);
    procedure LoadFromRecord(const AConfig : frmEmailServerConfigRec);

    property Config : frmEmailServerConfigRec read FConfig;
  end;

var
  EmailServerConfigF: TEmailServerConfigF;

implementation

{$R *.dfm}

function TEmailServerConfigF.Validate: Boolean;
begin
  Result := False;
  if Trim(edtSmtpHost.Text) = '' then begin
    ShowMessage('SMTP 서버 주소를 입력하세요.');
    edtSmtpHost.SetFocus; Exit;
  end;
  if Trim(edtSmtpPort.Text) = '' then begin
    ShowMessage('SMTP 포트 번호를 입력하세요.');
    edtSmtpPort.SetFocus; Exit;
  end;
  if Trim(edtSmtpID.Text) = '' then begin
    ShowMessage('서버 ID를 입력하세요.');
    edtSmtpID.SetFocus; Exit;
  end;
  if Trim(edtRecvHost.Text) = '' then begin
    ShowMessage('받는 메일 서버 주소를 입력하세요.');
    edtRecvHost.SetFocus; Exit;
  end;
  if Trim(edtRecvPort.Text) = '' then begin
    ShowMessage('받는 메일 서버 포트를 입력하세요.');
    edtRecvPort.SetFocus; Exit;
  end;
  Result := True;
end;

procedure TEmailServerConfigF.btnSaveClick(Sender: TObject);
begin
  if not Validate then Exit;
  try
    SaveConfigToJson();
  except
    on E: Exception do
      MessageDlg(#51200#51109#32#49892#54056#58#32 + E.Message, mtError, [mbOK], 0);
  end;
  // 여기에 INI 파일 또는 DB 저장 로직 추가
  ShowMessage('설정이 저장되었습니다.');
end;

procedure TEmailServerConfigF.btnTestClick(Sender: TObject);
var
  LMsg: string;
begin
  if not Validate then Exit;

  TestEmailServerConnection(LMsg);
  // 여기에 IdSMTP 등을 이용한 연결 테스트 로직 추가
//  ShowMessage(Format('서버 %s:%s 연결 테스트 (미구현)',
//    [edtSmtpHost.Text, edtSmtpPort.Text]));
end;

procedure TEmailServerConfigF.LoadConfigFromJson(const AJson: string);
var
  Root: TJSONObject;
  SendServer: TJSONObject;
  ReceiveServer: TJSONObject;
begin
  FConfigJson := AJson;

  Root := TJSONObject.ParseJSONValue(AJson) as TJSONObject;

  if not Assigned(Root) then
    raise Exception.Create('JSON 형식이 올바르지 않습니다.');

  try
    SendServer := Root.GetValue<TJSONObject>('SMTPServer');
    ReceiveServer := Root.GetValue<TJSONObject>('POPServer');

    if Assigned(SendServer) then
    begin
      edtSmtpHost.Text := SendServer.GetValue<string>('host', '');
      edtSmtpPort.Text := SendServer.GetValue<Integer>('port', 0).ToString;
      edtSmtpID.Text := SendServer.GetValue<string>('serverId', '');
      edtSmtpPW.Text := SendServer.GetValue<string>('password', '');
    end;

    if Assigned(ReceiveServer) then
    begin
      edtRecvHost.Text := ReceiveServer.GetValue<string>('host', '');
      edtRecvPort.Text := ReceiveServer.GetValue<Integer>('port', 0).ToString;
    end;
  finally
    Root.Free;
  end;
end;

procedure TEmailServerConfigF.LoadFromRecord(const AConfig: frmEmailServerConfigRec);
begin
  edtSmtpHost.Text := AConfig.SmtpHost;
  edtSmtpPort.Text := IntToStr(AConfig.SmtpPort);
  edtSmtpID.Text   := AConfig.SmtpID;
  edtSmtpPW.Text   := AConfig.SmtpPW;
  edtRecvHost.Text := AConfig.RecvHost;
  edtRecvPort.Text := IntToStr(AConfig.RecvPort);
end;

procedure TEmailServerConfigF.SaveConfigToJson();
var
  Root: TJSONObject;
  SendServer: TJSONObject;
  ReceiveServer: TJSONObject;
  SendPort: Integer;
  ReceivePort: Integer;
begin
  SendPort := StrToInt(Trim(edtSMTPPort.Text));
  ReceivePort := StrToInt(Trim(edtRecvPort.Text));

  Root := TJSONObject.Create;
  SendServer := TJSONObject.Create;
  ReceiveServer := TJSONObject.Create;
  try
    SendServer.AddPair('host', Trim(edtSMTPHost.Text));
    SendServer.AddPair('port', TJSONNumber.Create(SendPort));
    SendServer.AddPair('serverId', Trim(edtSMTPID.Text));
    SendServer.AddPair('password', edtSMTPPW.Text);

    ReceiveServer.AddPair('host', Trim(edtRecvHost.Text));
    ReceiveServer.AddPair('port', TJSONNumber.Create(ReceivePort));

    Root.AddPair('SMTPServer', SendServer);
    SendServer := nil;
    Root.AddPair('POPServer', ReceiveServer);
    ReceiveServer := nil;

    FConfigJson := Root.ToString;

//    TFile.WriteAllText(AFileName, FConfigJson, TEncoding.UTF8);
  finally
    ReceiveServer.Free;
    SendServer.Free;
    Root.Free;
  end;

end;

procedure TEmailServerConfigF.SaveToRecord(out AConfig: frmEmailServerConfigRec);
begin
  AConfig.SmtpHost := Trim(edtSmtpHost.Text);
  AConfig.SmtpPort := StrToIntDef(Trim(edtSmtpPort.Text), 465);
  AConfig.SmtpID   := Trim(edtSmtpID.Text);
  AConfig.SmtpPW   := edtSmtpPW.Text;          // 패스워드는 Trim 제외
  AConfig.RecvHost := Trim(edtRecvHost.Text);
  AConfig.RecvPort := StrToIntDef(Trim(edtRecvPort.Text), 993);
end;


function TEmailServerConfigF.TestEmailServerConnection(
  out AMessage: string): Boolean;
var
  SMTP: TIdSMTP;
  IMAP: TIdIMAP4;
  SMTPSSL: TIdSSLIOHandlerSocketOpenSSL;
  IMAPSSL: TIdSSLIOHandlerSocketOpenSSL;
begin
  Result := False;
  AMessage := '';

  if not Validate() then
  begin
    AMessage := '입력값이 올바르지 않습니다.';
    Exit;
  end;

  SMTP := TIdSMTP.Create(nil);
  IMAP := TIdIMAP4.Create(nil);
  SMTPSSL := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  IMAPSSL := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  try
    SMTPSSL.SSLOptions.Method := sslvTLSv1_2;
    SMTPSSL.SSLOptions.Mode := sslmClient;

    SMTP.IOHandler := SMTPSSL;
    SMTP.Host := Trim(edtSMTPHost.Text);
    SMTP.Port := StrToInt(Trim(edtSMTPPort.Text));
    SMTP.Username := Trim(edtSMTPID.Text);
    SMTP.Password := edtSMTPPW.Text;
    SMTP.AuthType := satDefault;

    if SMTP.Port = 465 then
      SMTP.UseTLS := utUseImplicitTLS
    else
      SMTP.UseTLS := utUseExplicitTLS;

    try
      SMTP.Connect;
      SMTP.Authenticate;
      SMTP.Disconnect;
    except
      on E: Exception do
      begin
        AMessage := '전송 서버 연결 실패: ' + E.Message;
        Exit;
      end;
    end;

    IMAPSSL.SSLOptions.Method := sslvTLSv1_2;
    IMAPSSL.SSLOptions.Mode := sslmClient;

    IMAP.IOHandler := IMAPSSL;
    IMAP.Host := Trim(edtRecvHost.Text);
    IMAP.Port := StrToInt(Trim(edtRecvPort.Text));
    IMAP.Username := Trim(edtSMTPID.Text);
    IMAP.Password := edtSMTPPW.Text;

    if IMAP.Port = 993 then
      IMAP.UseTLS := utUseImplicitTLS
    else
      IMAP.UseTLS := utUseExplicitTLS;

    try
      IMAP.Connect;
      IMAP.Disconnect;
    except
      on E: Exception do
      begin
        AMessage := '받는 메일 서버 연결 실패: ' + E.Message;
        Exit;
      end;
    end;

    Result := True;
    AMessage := '이메일 서버 연결 테스트가 성공했습니다.';
  finally
    if SMTP.Connected then
      SMTP.Disconnect;

    if IMAP.Connected then
      IMAP.Disconnect;

    IMAPSSL.Free;
    SMTPSSL.Free;
    IMAP.Free;
    SMTP.Free;
  end;
end;

{ frmEmailServerConfigRec }

procedure frmEmailServerConfigRec.Clear;
begin
  SmtpHost := '';
  SmtpPort := 465;
  SmtpID   := '';
  SmtpPW   := '';
  RecvHost := '';
  RecvPort := 993;
end;

end.
