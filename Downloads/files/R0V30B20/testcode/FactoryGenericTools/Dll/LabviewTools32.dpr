library
  LabviewTools32;

uses
  Classes,
  SysUtils,
  DateUtils,
  Windows,
  TV_Extend;

const
  C_CRLF = #13#10;
  C_SearchItem = 'Checksum=';

type
  T_FileItem = (fiAll, fiCreationTime, fiAccessTime, fiWriteTime);

  T_WordQueue = Array of Word;

var
  V_Search: TMatch;
  V_DataList: TStringList;

{$R *.res}

function xIsFileReadOnly(const c_FilePath: PChar): Boolean;
begin
  Result := (GetFileAttributes(PChar(c_FilePath)) and FILE_ATTRIBUTE_READONLY) > 0;
end;

function xDoFileReadOnly(const c_FilePath: PChar): Boolean;
begin
  Result := SetFileAttributes(PChar(c_FilePath), GetFileAttributes(PChar(c_FilePath)) or FILE_ATTRIBUTE_READONLY);
end;

function xUnDoFileReadOnly(const c_FilePath: PChar): Boolean;
begin
  Result := SetFileAttributes(PChar(c_FilePath), GetFileAttributes(PChar(c_FilePath)) and (not FILE_ATTRIBUTE_READONLY));
end;

function xGetFileTimeString(const c_SystemTime: SystemTime): PChar;
begin
  With c_SystemTime do
    Result := PChar(Format('%0.4d-%0.2d-%0.2d %0.2d:%0.2d:%0.2d', [wYear, wMonth, wDay, wHour, wMinute, wSecond]));
end;

function xCalculateChecksum(const c_DataArray: T_WordQueue): Word;
const
  c_Signiture = Word($0409);
  c_Polynomial = Word($1960);
var
  v_Checksum, v_CheckResult: Word;
  v_X, v_Y: Cardinal;
begin
  Result := 0;
  if Length(c_DataArray) = 0 then Exit;
  v_Checksum := c_Signiture;
  for v_X := 0 to High(c_DataArray) do
  begin
    v_Checksum := v_Checksum xor c_DataArray[v_X];
    for v_Y := 0 to 7 do
    begin
       v_CheckResult := v_Checksum and 1;
       if (v_CheckResult = 1) then
       begin
         v_Checksum := v_Checksum shr 1;
         v_Checksum := v_Checksum xor c_Polynomial;
       end else
       begin
         v_Checksum := v_Checksum shr 1;
       end;
    end;
  end;
  Result := v_Checksum;
end;

function xCalculateChecksumText(const c_DataString: String): Word;
var
  v_X, v_Y: Integer;
  v_WQ: T_WordQueue;
begin
  v_X := 1;
  v_Y := 0;
  while (v_X < Length(c_DataString)) do
  begin
    SetLength(v_WQ, Length(v_WQ) + 1);
    v_WQ[v_Y] := Ord(c_DataString[v_X]) * 256 + Ord(c_DataString[v_X + 1]);
    v_X := v_X + 2;
    v_Y := v_Y + 1;
  end;
  Result := xCalculateChecksum(v_WQ);
end;

// Export procedures and functions

procedure xByteToChar(const c_Byte: Byte; var v_Char: PChar); Export; StdCall;
begin
  v_Char := PChar(Chr(c_Byte));
end;

function xCharToByte(const c_Character: PChar): Byte; Export; StdCall;
begin
  Result := Ord(c_Character[0]);
end;

function xGetFileDateTime(const c_FilePath: PChar; var v_CreationTime, v_AccessTime, v_WriteTime: TSystemTime): Integer; Export; StdCall;
var
  v_ReadOnly: Boolean;
  v_File: THandle;
  v_FileCreationTime, v_FileAccessTime, v_FileWriteTime: TFileTime;
begin
  v_ReadOnly := False;
  v_File := 0;
  try
    v_ReadOnly := xIsFileReadOnly(c_FilePath);
    if v_ReadOnly then xUnDoFileReadOnly(c_FilePath);
    //v_File := FileOpen(c_FilePath, fmOpenReadWrite);
    v_File := FileOpen(c_FilePath, fmOpenRead);
    Result := Integer(GetFileTime(v_File, @v_FileCreationTime, @v_FileAccessTime, @v_FileWriteTime));
    Result := Integer(FileTimeToLocalFileTime(v_FileCreationTime, v_FileCreationTime));
    Result := Integer(FileTimeToSystemTime(v_FileCreationTime, v_CreationTime));
    Result := Integer(FileTimeToLocalFileTime(v_FileAccessTime, v_FileAccessTime));
    Result := Integer(FileTimeToSystemTime(v_FileAccessTime, v_AccessTime));
    Result := Integer(FileTimeToLocalFileTime(v_FileWriteTime, v_FileWriteTime));
    Result := Integer(FileTimeToSystemTime(v_FileWriteTime, v_WriteTime));
  finally
    FileClose(v_File);
    if v_ReadOnly then xDoFileReadOnly(c_FilePath);
  end;
end;

function xSetFileDateTime(const c_FilePath:PChar; const c_SystemTime: TSystemTime; const c_Selection: T_FileItem = fiAll): Integer; Export; StdCall;
var
  v_ReadOnly: Boolean;
  v_FormatSettings: TFormatSettings;
  v_FileTime: TFileTime;
  v_File: Integer;
begin
  Result := 0;
  v_ReadOnly := False;
  v_File := 0;
  GetLocaleFormatSettings(0, v_FormatSettings);
  v_FormatSettings.ShortDateFormat := 'yyyy-mm-dd';
  SystemTimeToFileTime(c_SystemTime, v_FileTime);
  LocalFileTimeToFileTime(v_FileTime, v_FileTime);
  try
    v_ReadOnly := xIsFileReadOnly(c_FilePath);
    if v_ReadOnly then xUnDoFileReadOnly(c_FilePath);
    v_File := FileOpen(c_FilePath, fmOpenReadWrite);
    case c_Selection of
               fiAll:Result := Integer(SetFileTime(v_File, @v_FileTime, @v_FileTime, @v_FileTime));
      fiCreationTime:Result := Integer(SetFileTime(v_File, @v_FileTime, Nil, Nil));
        fiAccessTime:Result := Integer(SetFileTime(v_File, Nil, @v_FileTime, Nil));
         fiWriteTime:Result := Integer(SetFileTime(v_File, Nil, Nil, @v_FileTime));
    end;
  finally
    FileClose(v_File);
    if v_ReadOnly then xDoFileReadOnly(c_FilePath);
  end;
end;

function xGetChecksumFile(const c_FilePath: PChar; var v_Checksum: Word): Integer; Export; StdCall;
const
  c_MaxRec = 10240;
var
  v_X, v_TotalRead, v_ActualRead: Cardinal;
  v_DataArray: T_WordQueue;
  v_DataBuffer: Array [0 .. c_MaxRec - 1] of Word;
  v_File: File;
begin
  try
    Result := 0;
    FileMode := 0; // 0=Read, 1=Write, 2=Read/Write
    v_TotalRead := 0;
    AssignFile(v_File, String(c_FilePath));
    Reset(v_File, 2);
    SetLength(v_DataArray, FileSize(v_File));
    while not Eof(v_File) do
    begin
      BlockRead(v_File, v_DataBuffer, c_MaxRec, v_ActualRead);
      for v_X := 0 to v_ActualRead - 1 do
      begin
        v_DataArray[v_TotalRead + v_X] := v_DataBuffer[v_X];
      end;
      v_TotalRead := v_TotalRead + v_ActualRead;
    end;
    CloseFile(v_File);
    v_Checksum := xCalculateChecksum(v_DataArray);
  except
    CloseFile(v_File);
    Result := 1;
  end;
end;

function xValidationControlTextFile(const c_FilePath: PChar; var v_Checksum: Boolean): Integer; Export; StdCall;
var
  v_DataChecksum, v_ReferenceChecksum, v_CalculatedChecksum: String;
begin
  V_DataList := TStringList.Create;
  try
    V_DataList.Clear;
    try
      V_DataList.LoadFromFile(c_FilePath);
      V_Search := xMatch(C_SearchItem, V_DataList.GetText);
      if not V_Search.Found then
      begin
        v_Checksum := False;
      end else
      begin
        v_DataChecksum := V_Search.Before;
        V_Search := xMatch(C_CRLF, V_Search.After);
        if V_Search.Found then
        begin
          v_ReferenceChecksum := Trim(V_Search.Before);
        end else
        begin
          v_ReferenceChecksum := Trim(V_Search.After);
        end;
        try
          v_CalculatedChecksum := Uppercase(IntToHex(xCalculateChecksumText(v_DataChecksum), 4));
        except
          v_CalculatedChecksum := '0000';
        end;
        v_Checksum := (v_ReferenceChecksum = v_CalculatedChecksum);
      end;
      Result := 0;
    except
      Result := 1;
    end;
  finally
    V_DataList.Free;
  end;
end;

function xGetChecksumTextFile(const c_FilePath: PChar; var v_ReferenceChecksum, v_CalculatedChecksum: Word): Integer; Export; StdCall;
var
  v_DataChecksum: String;
begin
  V_DataList := TStringList.Create;
  try
    V_DataList.Clear;
    try
      V_DataList.LoadFromFile(c_FilePath);
      V_Search := xMatch(C_SearchItem, V_DataList.GetText);
      if not V_Search.Found then
      begin
        v_DataChecksum := V_Search.After;
        v_ReferenceChecksum := 0;
      end else
      begin
        v_DataChecksum := V_Search.Before;
        V_Search := xMatch(C_CRLF, V_Search.After);
        try
          if V_Search.Found then
          begin
            v_ReferenceChecksum := Word(StrToInt(Concat('$', Trim(V_Search.Before))));
          end else
          begin
            v_ReferenceChecksum := Word(StrToInt(Concat('$', Trim(V_Search.After))));
          end;
        except
          v_ReferenceChecksum := 0;
        end;
      end;
      v_CalculatedChecksum := xCalculateChecksumText(v_DataChecksum);
      Result := 0;
    except
      Result := 1;
    end;
  finally
    V_DataList.Free;
  end;
end;

function xSetChecksumTextFile(const c_FilePath, c_PrefixFront, c_PrefixRear: PChar): Integer; Export; StdCall;
var
  v_DataChecksum, v_CalculatedChecksum: String;
begin
  V_DataList := TStringList.Create;
  try
    V_DataList.Clear;
    try
      V_DataList.LoadFromFile(c_FilePath);
      V_Search := xMatch(C_SearchItem, V_DataList.GetText);
      if V_Search.Found then
      begin
        v_DataChecksum := V_Search.Before;
        v_CalculatedChecksum := IntToHex(xCalculateChecksumText(v_DataChecksum), 4);
        V_Search := xMatch(C_CRLF, V_Search.After);
        V_DataList.SetText(PChar(Concat(v_DataChecksum, C_SearchItem, v_CalculatedChecksum, C_CRLF, V_Search.After)));
      end else
      begin
        v_DataChecksum := Concat(V_Search.After, c_PrefixFront);
        v_CalculatedChecksum := IntToHex(xCalculateChecksumText(v_DataChecksum), 4);
        V_DataList.SetText(PChar(Concat(v_DataChecksum, C_SearchItem, v_CalculatedChecksum, C_CRLF, c_PrefixRear)));
      end;
      V_DataList.SaveToFile(c_FilePath);
      Result := 0;
    except
      Result := 1;
    end;
  finally
    V_DataList.Free;
  end;
end;

procedure xGregorianToJulian(const Year, Month, Day: Integer; out Number: Integer); export; stdcall;
begin
  Number := (1461 * (Year + 4800 + (Month - 14) div 12)) div 4 +
            (367 * (Month - 2 - 12 * ((Month - 14) div 12))) div 12 -
            (3 * ((Year + 4900 + (Month - 14) div 12) div 100)) div 4 +
            Day - 32076;
end;

procedure xJulianToGregorian(const Number: Integer; out Year, Month, Day: Integer); export; stdcall;
var
  L, N: Integer;
begin
  L := Trunc(Number) + 68570;
  N := 4 * L div 146097;
  L := L - (146097 * N + 3) div 4;
  Year := 4000 * (L + 1) div 1461001;
  L := L - 1461 * Year div 4 + 31;
  Month := 80 * L div 2447;
  Day := L - 2447 * Month div 80;
  L := Month div 11;
  Month := Month + 2 - 12 * L;
  Year := 100 * (N - 49) + Year + L;
end;

exports xByteToChar;
exports xCharToByte;
exports xGregorianToJulian;
exports xJulianToGregorian;
exports xGetFileDateTime;
exports xSetFileDateTime;
exports xGetChecksumFile;
exports xValidationControlTextFile;
exports xGetChecksumTextFile;
exports xSetChecksumTextFile;

begin
end.

