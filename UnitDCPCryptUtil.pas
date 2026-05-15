unit UnitDCPCryptUtil;

interface

uses
  System.SysUtils, System.NetEncoding,
  DCPsha1; // DCPcrypt 라이브러리 사용 예시

//function DecryptMariaDBPass(const EncryptedHex, Key: string): string;
//var
//  Cipher: TDCP_aes;
//  DataRaw, KeyRaw: TBytes;
//  DecryptedBytes: TBytes;
//begin
//  // 1. UnHex (16진수 문자열 -> 바이트 배열)
//  DataRaw := THexEncoding.Medium.Decode(EncryptedHex);
//
//  // 2. 키 처리 (MariaDB 방식: 16바이트로 맞춤)
//  SetLength(KeyRaw, 16);
//  FillChar(KeyRaw[0], 16, 0);
//  Move(Pointer(TEncoding.UTF8.GetBytes(Key))^, KeyRaw[0], Min(Length(Key), 16));
//
//  // 3. AES-ECB 복호화
//  Cipher := TDCP_aes.Create(nil);
//  try
//    Cipher.Init(KeyRaw[0], 128, nil); // ECB는 IV가 nil
//    SetLength(DecryptedBytes, Length(DataRaw));
//    Cipher.DecryptECB(DataRaw[0], DecryptedBytes[0]);
//
//    // 4. Using UTF8 (바이트를 문자열로 변환)
//    Result := TEncoding.UTF8.GetString(DecryptedBytes).TrimRight([#0]);
//  finally
//    Cipher.Free;
//  end;
//end;

implementation

end.
