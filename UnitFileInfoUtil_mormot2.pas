unit UnitFileInfoUtil_mormot2;

interface

uses Winapi.Windows, System.Classes, System.SysUtils, System.DateUtils,
  mormot.core.os;

type
  TFileInfoUtil_Mormot = class
    class function GetBuildDateByPEImage: TDateTime;
    class function GetBuildDateByPJVerInfo(const AFileName: string = ''): TDateTime;
    class function GetCommentByPJVerInfo(const AFileName: string): string;
    class function GetInternalNameByPJVerInfo(const AFileName: string): string;
    class function GetFileVersionByPJVerInfo(const AFileName: string): string;
    class function GetFileVersionListByPJVerInfoFromFolder(const AFolder: string; const AIsOnlyExeDll: Boolean = true): TStringList;
    //AList : Full Path FileName List
    //각 항목을 FileName=version 형식으로 반환함
    class function GetFileVersionListByPJVerInfoFromList(AList: TStringList): integer;

    class function IsValidFileName(const AFileName: string): Boolean;
    class function GetValidFileName(const AFileName: string): string;

    class function Isx64PEImage(const AStream: TStream): Boolean; overload;
    class function Isx64PEImage(const APEImageFileName: string): Boolean; overload;
    class function GetProductVersionStr(const AFileName: string = ''): string;
  end;

implementation

uses
  mormot.misc.pecoff;

type
  TFileNameCollector = class(TDirectoryBrowser)
  private
    fList: TStringList;
  protected
    function OnFile(const FileInfo: TSearchRec; const FullFileName: TFileName): boolean; override;
  public
    constructor Create(const Directory: TFileName; const FileMasks: array of TFileName;
      AList: TStringList; Recursive: boolean = false);
  end;

constructor TFileNameCollector.Create(const Directory: TFileName;
  const FileMasks: array of TFileName; AList: TStringList; Recursive: boolean);
begin
  inherited Create(Directory, FileMasks, Recursive);
  fList := AList;
end;

function TFileNameCollector.OnFile(const FileInfo: TSearchRec; const FullFileName: TFileName): boolean;
begin
  fList.Add(FullFileName);
  Result := True;
end;

// AFileName = '' 이면 현재 실행중인 프로세스(Executable)의 버전 정보를,
// 아니면 지정된 파일의 버전 정보를 조회한다.
// AOwned = True 인 경우 호출자가 반환된 TFileVersion 을 Free 해야 한다.
function TFileInfoUtil_Mormot_InternalFileVersion(const AFileName: string; out AOwned: Boolean): TFileVersion;
begin
  if AFileName = '' then
  begin
    GetExecutableVersion;
    Result := Executable.Version;
    AOwned := False;
  end
  else
  begin
    Result := TFileVersion.Create(AFileName);
    Result.RetrieveInformationFromFileName;
    AOwned := True;
  end;
end;

class function TFileInfoUtil_Mormot.GetBuildDateByPEImage: TDateTime;
var
  LLoader: TSynPELoader;
  LUtcTime: TDateTime;
begin
  Result := 0;

  LLoader := TSynPELoader.Create;
  try
    if LLoader.LoadFromFile(ParamStr(0)) then
    begin
      LUtcTime := UnixToDateTime(LLoader.CoffHeader.TimeDateStamp);
      Result := TTimeZone.Local.ToLocalTime(LUtcTime);
    end;
  finally
    LLoader.Free;
  end;
end;

class function TFileInfoUtil_Mormot.GetBuildDateByPJVerInfo(const AFileName: string): TDateTime;
var
  LInfo: TFileVersion;
  LOwned: Boolean;
begin
  LInfo := TFileInfoUtil_Mormot_InternalFileVersion(AFileName, LOwned);
  try
    Result := LInfo.BuildDateTime;
  finally
    if LOwned then
      LInfo.Free;
  end;
end;

class function TFileInfoUtil_Mormot.GetCommentByPJVerInfo(const AFileName: string): string;
var
  LInfo: TFileVersion;
  LOwned: Boolean;
begin
  LInfo := TFileInfoUtil_Mormot_InternalFileVersion(AFileName, LOwned);
  try
    Result := LInfo.Comments;
  finally
    if LOwned then
      LInfo.Free;
  end;
end;

class function TFileInfoUtil_Mormot.GetInternalNameByPJVerInfo(const AFileName: string): string;
var
  LInfo: TFileVersion;
  LOwned: Boolean;
begin
  LInfo := TFileInfoUtil_Mormot_InternalFileVersion(AFileName, LOwned);
  try
    Result := LInfo.InternalName;
  finally
    if LOwned then
      LInfo.Free;
  end;
end;

class function TFileInfoUtil_Mormot.GetFileVersionByPJVerInfo(const AFileName: string): string;
var
  LInfo: TFileVersion;
  LOwned: Boolean;
begin
  LInfo := TFileInfoUtil_Mormot_InternalFileVersion(AFileName, LOwned);
  try
    Result := LInfo.FileVersion;
  finally
    if LOwned then
      LInfo.Free;
  end;
end;

class function TFileInfoUtil_Mormot.GetFileVersionListByPJVerInfoFromFolder(const AFolder: string; const AIsOnlyExeDll: Boolean): TStringList;
var
  LCollector: TFileNameCollector;
begin
  Result := TStringList.Create;

  if AIsOnlyExeDll then
    LCollector := TFileNameCollector.Create(AFolder, ['*.exe', '*.dll'], Result, False)
  else
    LCollector := TFileNameCollector.Create(AFolder, ['*.*'], Result, False);

  try
    LCollector.Run;
  finally
    LCollector.Free;
  end;

  GetFileVersionListByPJVerInfoFromList(Result);
end;

class function TFileInfoUtil_Mormot.GetFileVersionListByPJVerInfoFromList(AList: TStringList): integer;
var
  i: integer;
  LFileName: string;
  LInfo: TFileVersion;
begin
  Result := -1;

  for i := 0 to AList.Count - 1 do
  begin
    LFileName := AList.Strings[i];

    if FileExists(LFileName) then
    begin
      LInfo := TFileVersion.Create(LFileName);
      try
        LInfo.RetrieveInformationFromFileName;
        AList.Strings[i] := LFileName + '=' + LInfo.FileVersion;
      finally
        LInfo.Free;
      end;
    end
    else
      AList.Strings[i] := LFileName + '=';
  end;

  Result := AList.Count;
end;

class function TFileInfoUtil_Mormot.IsValidFileName(const AFileName: string): Boolean;
const
  InvalidChars: set of Char = ['\', '/', ':', '*', '?', '"', '<', '>', '|'];
var
  i: integer;
begin
  Result := (AFileName <> '') and (Length(AFileName) <= MAX_PATH);

  if Result then
  begin
    for i := 1 to Length(AFileName) do
    begin
      if AFileName[i] in InvalidChars then
      begin
        Result := False;
        Break;
      end;
    end;
  end;
end;

class function TFileInfoUtil_Mormot.GetValidFileName(const AFileName: string): string;
const
  InvalidChars: set of Char = ['\', '/', ':', '*', '?', '"', '<', '>', '|'];
var
  i: integer;
  LStr, LFilePath, LFileName: string;
  LIsModified: Boolean;
begin
  Result := '';
  LIsModified := False;

  LFilePath := ExtractFilePath(AFileName);
  LFileName := ExtractFileName(AFileName);

  if (LFileName <> '') and (Length(LFileName) <= MAX_PATH) then
  begin
    for i := 1 to Length(LFileName) do
    begin
      if LFileName[i] in InvalidChars then
      begin
        LStr := StringReplace(LFileName, LFileName[i], '_', [rfReplaceAll]);
        LIsModified := True;
      end;
    end;//for

    if LIsModified then
      Result := LFilePath + LStr
    else
      Result := AFileName;
  end;
end;

class function TFileInfoUtil_Mormot.Isx64PEImage(const AStream: TStream): Boolean;
var
  LDOSHeader: TImageDOSHeader;
  LFileHeader: TImageFileHeader;
begin
  Result := False;

  if AStream.Read(LDOSHeader, SizeOf(LDOSHeader)) <> SizeOf(LDOSHeader) then
    Exit;
  if (LDOSHeader.e_magic <> DOS_HEADER_MAGIC) or (LDOSHeader.e_lfanew = 0) then
    Exit;
  if AStream.Size < LDOSHeader.e_lfanew then
    Exit;

  AStream.Position := LDOSHeader.e_lfanew;
  if AStream.Read(LFileHeader, SizeOf(LFileHeader)) <> SizeOf(LFileHeader) then
    Exit;
  if LFileHeader.Signature <> PE_HEADER_MAGIC then
    Exit;

  Result := LFileHeader.Arch <> caI386;
end;

class function TFileInfoUtil_Mormot.Isx64PEImage(const APEImageFileName: string): Boolean;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APEImageFileName, fmOpenRead or fmShareDenyNone);
  try
    Result := Isx64PEImage(LStream);
  finally
    LStream.Free;
  end;
end;

class function TFileInfoUtil_Mormot.GetProductVersionStr(const AFileName: string): string;
var
  LFileName: string;
  LLoader: TSynPELoader;
begin
  Result := '0.0.0.0';

  if AFileName = '' then
    LFileName := ParamStr(0)
  else
    LFileName := AFileName;

  LLoader := TSynPELoader.Create;
  try
    if LLoader.LoadFromFile(LFileName) and LLoader.ParseResources and
       (LLoader.FixedFileInfo <> nil) then
      Result := Format('%d.%d.%d.%d', [
        HiWord(LLoader.FixedFileInfo.ProductVersionMS),
        LoWord(LLoader.FixedFileInfo.ProductVersionMS),
        HiWord(LLoader.FixedFileInfo.ProductVersionLS),
        LoWord(LLoader.FixedFileInfo.ProductVersionLS)
      ]);
  finally
    LLoader.Free;
  end;
end;

end.
