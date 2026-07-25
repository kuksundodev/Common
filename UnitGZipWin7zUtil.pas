unit UnitGZipWin7zUtil;

interface

uses System.Classes, SysUtils,
  mormot.core.base,
  mormot.core.os,
  mormot.core.text,
  mormot.core.buffers,
  mormot.core.unicode,
  mormot.lib.z,
  mormot.core.zip,
  mormot.lib.win7zip;

type
  TGZipWin7z_mormot2 = class
  public
    //7z.dll ��ü ��� - ADllFullPathName�� ''�̸� �� ���� ���(JCL sevenzip.SevenzipLibraryDir�� ���� ���)
    class var DllFullPathName: string;

    //APackedFileName: ''�̸� ��ü ���� Decompress, �����ϸ� �� ���ϸ� ���� ����
    //ADllFullPathName: ''�̸� DllFullPathName Ŭ���� ���� ���
    class function DeCompressFileWithWin7zip(ASrcFile, ADestFile: string; ADllFullPathName: string='';
      APackedFileName: string=''; Anosubfolder: Boolean=False): Boolean;
    //Tgz���� ������ Ǯ�� .tar ������ Ǯ��-�ٽ��ѹ� ������ Ǯ��� .tar ������ Ǯ��
    //APackedFileName: ''�̸� ��� ���� Decompress
    //ADllFullPathName: ''�̸� DllFullPathName Ŭ���� ���� ���
    //Result: APackedFileName Contents
    //        APackedFileName = ''�̸� return = ''
    class function ExtractFromTgz2DirByPackedNameWin7Zip(ATgzFileName, ADestDir: string;
      APackedFileName: string=''; ADllFullPathName: string=''): string;
  end;

implementation

class function TGZipWin7z_mormot2.DeCompressFileWithWin7zip(ASrcFile, ADestFile,
  ADllFullPathName: string; APackedFileName: string; Anosubfolder: Boolean): Boolean;
var
  L7zip: I7zReader;
  LDllFullPathName: string;
begin
  LDllFullPathName := ADllFullPathName;

  if LDllFullPathName = '' then
    LDllFullPathName := DllFullPathName;

  L7zip := New7zReader(ASrcFile, fhUndefined, LDllFullPathName);

  if APackedFileName = '' then
    L7zip.ExtractAll(ADestFile, Anosubfolder)
  else
    L7zip.Extract(StringToUtf8(APackedFileName), ADestFile, Anosubfolder);

  Result := True;
end;

class function TGZipWin7z_mormot2.ExtractFromTgz2DirByPackedNameWin7Zip(ATgzFileName,
  ADestDir, APackedFileName, ADllFullPathName: string): string;
var
  LExtractFileName, LTarFileName: string;
begin
  Result := '';

  if ADestDir = '' then
    ADestDir := 'C:\temp\';

  ADestDir := IncludeTrailingPathDelimiter(ADestDir);

  //MPM11.tgz ������ c:\temp\�� "MPM11" ���Ϸ� Extract��(.tar ������ ����)
  DeCompressFileWithWin7zip(ATgzFileName, ADestDir, ADllFullPathName);

  LExtractFileName := ADestDir + ChangeFileExt(ExtractFileName(ATgzFileName), '');
  //c:\temp\MPM11 ������ �����ϸ�
  if FileExists(LExtractFileName) then
  begin
    LTarFileName := ChangeFileExt(LExtractFileName, '.tar');

    if FileExists(LTarFileName) then
      DeleteFile(LTarFileName);

    //MPM11 ������ MPM11.tar ���Ϸ� �̸� ������
    if RenameFile(LExtractFileName, LTarFileName) then
    begin
      //MPM11.tar ���Ͽ��� "home\db\interface.json" ������ c:\temp\�� Extract
      DeCompressFileWithWin7zip(LTarFileName, ADestDir, ADllFullPathName, APackedFileName);

      if APackedFileName <> '' then
      begin
        LExtractFileName := ADestDir + APackedFileName;

        if FileExists(LExtractFileName) then
        begin
          Result := Utf8ToString(StringFromFile(LExtractFileName));
        end;
      end;
    end;
  end;
end;

end.
