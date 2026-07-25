unit UnitSystemInfoUtil2;

interface

uses
  System.SysUtils, System.Hash,
  Winapi.ActiveX, System.Win.ComObj, System.Variants;

function GetUUIDByCPUInfo: string;

implementation

function GetUUIDByCPUInfo: string;
var
  Locator, Services, Processors, Processor: OleVariant;
  Enum: IEnumVariant;
  Value: OleVariant;
  Fetched: Cardinal;
  CpuId, Hash: string;
begin
  Result := '';

  CoInitialize(nil);
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Services := Locator.ConnectServer('.', 'root\CIMV2');

    Processors := Services.ExecQuery(
      'SELECT ProcessorId FROM Win32_Processor'
    );

    Enum := IUnknown(Processors._NewEnum) as IEnumVariant;
    if Enum.Next(1, Value, Fetched) = 0 then
    begin
      Processor := Value;
      CpuId := VarToStr(Processor.ProcessorId);
    end;

    if CpuId = '' then
      CpuId := GetEnvironmentVariable('COMPUTERNAME');

    Hash := THashMD5.GetHashString(CpuId).ToLower;

    Result :=
      Copy(Hash, 1, 8) + '-' +
      Copy(Hash, 9, 4) + '-' +
      Copy(Hash, 13, 4) + '-' +
      Copy(Hash, 17, 4) + '-' +
      Copy(Hash, 21, 12);
  finally
    CoUninitialize;
  end;
end;

end.
