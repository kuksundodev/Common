object EmailServerConfigF: TEmailServerConfigF
  Left = 0
  Top = 0
  Caption = #51060#47700#51068' '#49436#48260' '#49444#51221
  ClientHeight = 371
  ClientWidth = 520
  Color = clBtnFace
  Font.Charset = HANGEUL_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = #47569#51008' '#44256#46357
  Font.Style = []
  OldCreateOrder = True
  Position = poScreenCenter
  DesignSize = (
    520
    371)
  PixelsPerInch = 96
  TextHeight = 17
  object gbSMTP: TGroupBox
    Left = 16
    Top = 12
    Width = 488
    Height = 168
    Caption = ' '#48156#49888' (SMTP) '#49436#48260' '#49444#51221' '
    TabOrder = 0
    object lblSmtpHost: TLabel
      Left = 12
      Top = 28
      Width = 60
      Height = 17
      Caption = #49436#48260' '#51452#49548':'
    end
    object lblSmtpPort: TLabel
      Left = 300
      Top = 28
      Width = 60
      Height = 17
      Caption = #54252#53944' '#48264#54840':'
    end
    object lblSmtpID: TLabel
      Left = 12
      Top = 72
      Width = 47
      Height = 17
      Caption = #49436#48260' ID:'
    end
    object lblSmtpPW: TLabel
      Left = 12
      Top = 116
      Width = 55
      Height = 17
      Caption = #48708#48128#48264#54840':'
    end
    object edtSmtpHost: TEdit
      Left = 12
      Top = 48
      Width = 270
      Height = 25
      TabOrder = 0
    end
    object edtSmtpPort: TEdit
      Left = 300
      Top = 48
      Width = 80
      Height = 25
      TabOrder = 1
      Text = '465'
    end
    object edtSmtpID: TEdit
      Left = 12
      Top = 92
      Width = 476
      Height = 25
      TabOrder = 2
    end
    object edtSmtpPW: TEdit
      Left = 12
      Top = 136
      Width = 476
      Height = 25
      PasswordChar = '*'
      TabOrder = 3
    end
  end
  object gbRecv: TGroupBox
    Left = 16
    Top = 192
    Width = 488
    Height = 100
    Caption = ' '#49688#49888' (POP3/IMAP) '#49436#48260' '#49444#51221' '
    TabOrder = 1
    object lblRecvHost: TLabel
      Left = 12
      Top = 28
      Width = 91
      Height = 17
      Caption = #48155#45716' '#47700#51068' '#49436#48260':'
    end
    object lblRecvPort: TLabel
      Left = 340
      Top = 28
      Width = 60
      Height = 17
      Caption = #54252#53944' '#48264#54840':'
    end
    object edtRecvHost: TEdit
      Left = 12
      Top = 48
      Width = 310
      Height = 25
      TabOrder = 0
    end
    object edtRecvPort: TEdit
      Left = 340
      Top = 48
      Width = 80
      Height = 25
      TabOrder = 1
      Text = '993'
    end
  end
  object btnSave: TButton
    Left = 304
    Top = 304
    Width = 90
    Height = 32
    Anchors = [akLeft, akBottom]
    Caption = #54869#51064
    Default = True
    ModalResult = 1
    TabOrder = 2
    OnClick = btnSaveClick
    ExplicitTop = 316
  end
  object btnTest: TButton
    Left = 400
    Top = 304
    Width = 104
    Height = 32
    Anchors = [akLeft, akBottom]
    Caption = #50672#44208' '#53580#49828#53944
    TabOrder = 3
    OnClick = btnTestClick
    ExplicitTop = 316
  end
  object btnClose: TButton
    Left = 16
    Top = 304
    Width = 90
    Height = 32
    Anchors = [akLeft, akBottom]
    Cancel = True
    Caption = #45803#44592
    ModalResult = 8
    TabOrder = 4
    ExplicitTop = 316
  end
end
