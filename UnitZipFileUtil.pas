unit UnitZipFileUtil;

interface

uses classes, SysUtils, System.Zip, System.IOUtils, Winapi.ShellAPI, Winapi.Windows;

function SizeStr(const ASize: UInt32): string;
function ZipVerStr(const AVersion: UInt16): string;
function DOSFileDateToDateTime(FileDate: UInt32): Extended;
function GetZipFileInfo2StrList(AZipHeader: TZipHeader; AFileName: string; AFileComment: string=''): TStringList;
function IsValidZipFile(const AZipFileName: string): integer;
procedure AddText2Zip(const AZipFileName, AInternalName, AText: string);
procedure AddStream2Zip(const AZipFileName, AInternalName: string; AStream: TStream);
function ExtractFile2StreamByName(const AZipFileName, AInternalName: string): TStringStream;
function ExtractFile2StreamByNameFromOpenedZipFile(AZipFile: TZipFile; const AInternalName: string): TStringStream;
function GetIndexFromOpenedZipFile(AZipFile: TZipFile; const AInternalName: string): integer;
function GetIndexFromZipFile(const AZipFileName, AInternalName: string): integer;

function ExtractZipFileToSrcFile(const AZipFile, ADestDir: string; out AErrMsg: string): Boolean;
function FilesTozipEx(ASrcFiles: array of String; ASPath, ADestFile: String; out AErrMsg: string): Boolean;

implementation

function Copy_File(const Src, Dest: String; IsCopy: Boolean): Boolean;
var
  fPath     : String;
  FData     : TSHFileOpStruct;
  FFrom, FTo: array [0..MAX_PATH] of Char;

begin
  fPath := ExtractFileDir(Dest);
  if not DirectoryExists(fPath) then
    CreateDir(fPath);

  FillChar(FData, SizeOf(FData), 0);
  FillChar(FFrom, SizeOf(FFrom), 0);
  FillChar(FTo, SizeOf(FTo), 0);

  StrPCopy(FFrom, Src);
  StrPCopy(FTo, Dest);

  FData.fFlags := {FOF_ALLOWUNDO OR } FOF_NOCONFIRMATION or FOF_SILENT;
  FData.pFrom := @FFrom;
  FData.pTo := @FTo;

  FData.Wnd := 0;
  if IsCopy then FData.wFunc := FO_COPY
  else FData.wFunc := FO_MOVE;

  Result := (ShFileOperation(FData) = 0);
end;

function SizeStr(const ASize: UInt32): string;
begin
  if ASize < 1024 then
    Result := Format('%d bytes', [ASize])
  else
    Result := Format('%.0n KB', [ASize/1024]);
end;

function ZipVerStr(const AVersion: UInt16): string;
begin
  Result := Format('%.1n', [AVersion/10]);
end;

function DOSFileDateToDateTime(FileDate: UInt32): Extended;
begin
  Result := EncodeDate(LongRec(FileDate).Hi SHR 9 + 1980,
                       LongRec(FileDate).Hi SHR 5 and 15,
                       LongRec(FileDate).Hi and 31) +
            EncodeTime(LongRec(FileDate).Lo SHR 11,
                       LongRec(FileDate).Lo SHR 5 and 63,
                       LongRec(FileDate).Lo and 31 SHL 1, 0);
end;

function GetZipFileInfo2StrList(AZipHeader: TZipHeader; AFileName, AFileComment: string): TStringList;
begin
  Result := TStringList.Create;

  Result.Add('File Name : ' + AFileName);
  Result.Add('=======================================');
  Result.Add('Compression Method : ' + TZipCompressionToString(TZipCompression(AZipHeader.CompressionMethod)));
  Result.Add('Compressed Size : ' + SizeStr(AZipHeader.CompressedSize));
  Result.Add('UnCompressed Size : ' + SizeStr(AZipHeader.UnCompressedSize));
  Result.Add('Modifued Date/Time : ' + DateTimeToStr(DOSFileDateToDateTime(AZipHeader.ModifiedDateTime)));
  Result.Add('CRC : ' + IntToHex(AZipHeader.CRC32, 8));
  Result.Add('Zip Format Version : ' + ZipVerStr(AZipHeader.MadeByVersion));
  Result.Add('Minimum ZIP Version : ' + ZipVerStr(AZipHeader.RequiredVersion));
  Result.Add('Comment : ' + AFileComment);
end;

function IsValidZipFile(const AZipFileName: string): integer;
var
  LZipFile: TZipFile;
  LIsValid: Boolean;
begin
  Result := 0;

  if not FileExists(AZipFileName) then
  begin
    Result := -1;
    exit;
  end;

  LZipFile := TZipFile.Create;
  try
    LZipFile.Open(AZipFileName, zmRead);
//    LIsValid := LZipFile.IsValid()
  finally
    LZipFile.Free;
  end;
end;

procedure AddText2Zip(const AZipFileName, AInternalName, AText: string);
var
  LZip: TZipFile;
  LFileName: string;
  LSrcStream: TStringStream;
begin
  LSrcStream := TStringStream.Create(AText);
  LZip := TZipFile.Create;
  try
    LZip.Open(AZipFileName, zmWrite);
    LFileName := ExtractFileName(AInternalName);
    LZip.Add(LSrcStream, LFileName);
    LZip.Close;
  finally
    LZip.Free;
    LSrcStream.Free;
  end;
end;

procedure AddStream2Zip(const AZipFileName, AInternalName: string; AStream: TStream);
var
  LZip: TZipFile;
  LFileName: string;
begin
  LZip := TZipFile.Create;
  try
    if FileExists(AZipFileName) then
      LZip.Open(AZipFileName, zmReadWrite)
    else
      LZip.Open(AZipFileName, zmWrite);

    LFileName := ExtractFileName(AInternalName);
    LZip.Add(AStream, LFileName);
    LZip.Close;
  finally
    LZip.Free;
  end;
end;

function ExtractFile2StreamByName(const AZipFileName, AInternalName: string): TStringStream;
var
  LZip: TZipFile;
  LocalHeader: TZipHeader;
  LFileName: string;
  i: integer;
begin
  Result := nil;

  if not FileExists(AZipFileName) then
    exit;

  LZip := TZipFile.Create;
  try
    LZip.Open(AZipFileName, zmReadWrite);
    Result := ExtractFile2StreamByNameFromOpenedZipFile(LZip, LFileName);
    LZip.Close;
  finally
    LZip.Free;
  end;
end;

function ExtractFile2StreamByNameFromOpenedZipFile(AZipFile: TZipFile; const AInternalName: string): TStringStream;
var
  LocalHeader: TZipHeader;
  LFileName: string;
  i: integer;
begin
//  Result := TStringStream.Create;
  LFileName := ExtractFileName(AInternalName);
  i := GetIndexFromOpenedZipFile(AZipFile, LFileName);
  AZipFile.Read(i, TStream(Result), LocalHeader);  //Read 함수 내에서 TStream을 생성하여 반환함
end;

function GetIndexFromOpenedZipFile(AZipFile: TZipFile; const AInternalName: string): integer;
var
  i: integer;
  LFileName: string;
begin
  Result := -1;

  for i := 0 to AZipFile.FileCount - 1 do
  begin
    LFileName := AZipFile.FileNames[i];

    if LFileName = AInternalName then
    begin
      Result := i;
      Break;
    end;
  end;
end;

function GetIndexFromZipFile(const AZipFileName, AInternalName: string): integer;
var
  LZip: TZipFile;
begin
  Result := -1;

  if not FileExists(AZipFileName) then
    exit;

  LZip := TZipFile.Create;
  try
    LZip.Open(AZipFileName, zmRead);
    Result := GetIndexFromOpenedZipFile(LZip, AInternalName);
    LZip.Close;
  finally
    LZip.Free;
  end;
end;

function ExtractZipFileToSrcFile(const AZipFile, ADestDir: string; out AErrMsg: string): Boolean;
var
  Zip: TZipFile;
begin
  Result := False;

  // ZIP 파일 존재 여부
  if not FileExists(AZipFile) then
    Exit;

  // 대상 폴더 생성
  if not DirectoryExists(ADestDir) then
    ForceDirectories(ADestDir);

  Zip := TZipFile.Create;
  try
    try
      Zip.Open(AZipFile, zmRead);

      // 전체 압축 해제 (경로 유지, 기존 파일 자동 덮어쓰기)
      Zip.ExtractAll(ADestDir);

      Result := True;
    except
      on E: Exception do
      begin
        AErrMsg := '압축해제 에러: ' + Trim(E.Message);
      end;
    end;
  finally
    Zip.Close;
    Zip.Free;
  end;
end;

function FilesTozipEx(ASrcFiles: array of String; ASPath, ADestFile: String; out AErrMsg: string): Boolean;
var
  Zip: TZipFile;
  I: Integer;
  SrcFile: string;
begin
  Result := False;

  // 기존 ZIP 백업
  if FileExists(ADestFile) then
  begin
    Copy_File(ADestFile, ChangeFileExt(ADestFile, '.bak'), False);
    Sleep(3000);
  end;

  Zip := TZipFile.Create;
  try
    try
      // 새 ZIP 생성
      Zip.Open(ADestFile, zmWrite);

      for I := Low(ASrcFiles) to High(ASrcFiles) do
      begin
        SrcFile := TPath.Combine(ASPath, ASrcFiles[I]);
        if not FileExists(SrcFile) then
          Continue;

        // ZIP 내부에는 파일명만 들어가게
        Zip.Add(SrcFile, ExtractFileName(SrcFile));
      end;

      Result := FileExists(ADestFile);
    except
      on E: Exception do
      begin
        AErrMsg := '압축 에러: ' + Trim(E.Message);
      end;
    end;
  finally
    Zip.Close;
    Zip.Free;
  end;end;

end.
