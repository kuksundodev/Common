unit UnitDateUtil2;

interface

uses Windows, SysUtils, System.DateUtils, Vcl.ComCtrls, Winapi.CommCtrl;

type TDateTimePickerAccess = class(TDateTimePicker);

procedure PopupDateTimePicker(ADateTimePicker: TDateTimePicker; AX, AY: integer);
//Date만 가능함
function GetDateFromFormatStr(AFormat: string; ADateSep: Char; ADateStr: string): TDate;
function GetTimeFromFormatStr(AFormat: string; ATimeSep: Char; ATimeStr: string): TTime;
function AddTimeStrings(const Time1, Time2: string): string;
//두 날짜를 비교하여 더 큰 날짜를 반환
function GetMaxDate(const Date1, Date2: TDateTime): TDateTime;
//ADateTime : YYYYMMDDHHNNSS 형식의 문자열
function CustomStringToDateTime(const ADateTime: string): TDateTime;
function FormatStringToDateTime(const AValue: string): TDateTime;

implementation

procedure PopupDateTimePicker(ADateTimePicker: TDateTimePicker; AX, AY: integer);
var
  ST: TSystemTime;
  CalendarHandle: HWND;
begin
  ADateTimePicker.Date := Date;
  DateTimeToSystemTime(Date, ST);
  CalendarHandle := TDateTimePickerAccess(ADateTimePicker).GetCalendarHandle;
  MonthCal_SetCurSel(CalendarHandle, ST);
end;

function GetDateFromFormatStr(AFormat: string; ADateSep: Char; ADateStr: string): TDate;
var
  LDT: TDateTime;
  LFormat: TFormatSettings;
begin
  LFormat := TFormatSettings.Create;
  LFormat.DateSeparator := ADateSep;//'-';
  LFormat.ShortDateFormat := AFormat;
  Result := StrToDateTimeDef(ADateStr, IncYear(now, -2000), LFormat);
end;

function GetTimeFromFormatStr(AFormat: string; ATimeSep: Char; ATimeStr: string): TTime;
var
  LDT: TDateTime;
  LFormat: TFormatSettings;
begin
  LFormat := TFormatSettings.Create;
  LFormat.TimeSeparator := ATimeSep;//':';
  LFormat.ShortTimeFormat := AFormat;
  Result := StrToDateTime(ATimeStr, LFormat);
end;

//Time = hh:mm 형식임
//문자열로 된 두개의 시간을 더하여 문자열로 반환 함
function AddTimeStrings(const Time1, Time2: string): string;
var
  Hour1, Min1, Hour2, Min2: Integer;
  TotalMin, TotalHour: Integer;
begin
  // 각 시간 파싱
  Hour1 := StrToInt(Copy(Time1, 1, 2));
  Min1  := StrToInt(Copy(Time1, 4, 2));

  Hour2 := StrToInt(Copy(Time2, 1, 2));
  Min2  := StrToInt(Copy(Time2, 4, 2));

  // 총 시간 계산
  TotalMin := Min1 + Min2;
  TotalHour := Hour1 + Hour2 + (TotalMin div 60);
  TotalMin := TotalMin mod 60;

  // 'hh:mm' 형식으로 반환
  Result := Format('%.2d:%.2d', [TotalHour, TotalMin]);
end;

function GetMaxDate(const Date1, Date2: TDateTime): TDateTime;
begin
  if CompareDate(Date1, Date2) >= 0 then
    Result := Date1
  else
    Result := Date2;
end;

function CustomStringToDateTime(const ADateTime: string): TDateTime;
var
  Year, Month, Day, Hour, Min, Sec: Word;
begin
  // 글자 수가 정확히 14자리인지 검증 (예외 처리)
  if Length(ADateTime) <> 14 then
    raise EConvertError.Create('올바른 YYYYMMDDHHMISS 형식이 아닙니다.');

  // 문자열을 쪼개서 숫자로 변환
  Year  := StrToInt(Copy(ADateTime, 1, 4));
  Month := StrToInt(Copy(ADateTime, 5, 2));
  Day   := StrToInt(Copy(ADateTime, 7, 2));
  Hour  := StrToInt(Copy(ADateTime, 9, 2));
  Min   := StrToInt(Copy(ADateTime, 11, 2));
  Sec   := StrToInt(Copy(ADateTime, 13, 2));

  // TDateTime 타입으로 조립
  Result := EncodeDateTime(Year, Month, Day, Hour, Min, Sec, 0);
end;

function FormatStringToDateTime(const AValue: string): TDateTime;
var
  LSettings: TFormatSettings;
begin
  // 현재 시스템 설정을 기반으로 기본값 생성
  LSettings := TFormatSettings.Create;

  // 입력받을 문자열의 구조를 명시 (구분자가 없는 형태 지정)
  LSettings.ShortDateFormat := 'yyyymmdd';
  LSettings.LongTimeFormat := 'hhnnss'; // 델파이에서 분은 'nn'입니다. ('mm'은 월)
  LSettings.DateSeparator := #0;        // 구분자 없음
  LSettings.TimeSeparator := #0;        // 구분자 없음

  // 공백 없이 날짜와 시간이 붙어있으므로 구조에 맞게 공백 하나를 넣어 결합
  // '20260607081020' -> '20260607 081020'
  Result := StrToDateTime(Copy(AValue, 1, 8) + ' ' + Copy(AValue, 9, 6), LSettings);
end;

end.
