Library
  TestLabviewTools32;

Uses
  Classes,
  SysUtils,
  DateUtils,
  Windows;

Type
  TCharString = Array [0..5119] Of Char;

  TClusterRecord = Record
    Control: Boolean;
    Checksum: Word;
    StringLength: Cardinal;
    //Name: TCharString;
    Name: String;
  End;

  TClusterQueue = Array Of TClusterRecord;

  TPCharArray = Array of PChar;
  TStringArray = Array of String;

{$R *.res}

// ***** Export procedures and functions *****

Function xLoadChecksumFile(Const cFilePath: PChar; Var vDataArray: TClusterQueue; Var vRecordCount: Cardinal): Integer; Export; Stdcall;
Var
  I: Cardinal;
  F: File;

  Procedure ReadRecord(Const Device: File; Var DataRecord: TClusterRecord);
  Begin
    With DataRecord Do
    Begin
      FillChar(Name, SizeOf(Name), 0);
      BlockRead(Device, Control, 1);
      BlockRead(Device, Checksum, 2);
      BlockRead(Device, StringLength, 4);
      BlockRead(Device, Name, StringLength);
    End;
  End;

Begin
  Result := 0;
  FileMode := 0; // 0=Read, 1=Write, 2=Read/Write
  AssignFile(F, String(cFilePath));
  Try
    Reset(F, 1);
    BlockRead(F, vRecordCount, 4);
    I := 0;
    While Not Eof(F) Do
    Begin
      SetLength(vDataArray, I + 1);
      ReadRecord(F, vDataArray[I]);
      Inc(I);
    End;
    CloseFile(F);
  Except
    CloseFile(F);
    Result := 1;
  End;
End;

Function xSaveChecksumFile(Const cFilePath: PChar; Const cDataArray: TClusterQueue): Integer; Export; Stdcall;
Var
  I, RecordCounter: Cardinal;
  F: File;

  Procedure WriteRecord(Const Device: File; Const DataRecord: TClusterRecord);
  Begin
    With DataRecord Do
    Begin
      BlockWrite(Device, Control, 1);
      BlockWrite(Device, Checksum, 2);
      BlockWrite(Device, StringLength, 4);
      BlockWrite(Device, Name, StringLength);
    End;
  End;

Begin
  Result := 0;
  FileMode := 1; // 0=Read, 1=Write, 2=Read/Write
  AssignFile(F, cFilePath);
  Try
    Rewrite(F, 1);
    BlockWrite(F, RecordCounter, 4);
    For I := 0 To High(cDataArray) Do
    Begin
      WriteRecord(F, cDataArray[I]);
    End;
    CloseFile(F);
  Except
    CloseFile(F);
    Result := 1;
  End;
End;

Function xGetStringArray(Const cFilePath: PChar; Var vDataArray: TStringArray): Integer; Export; Stdcall;
Var
  I: Cardinal;
  //S: String;
  F: Text;
Begin
  Result := 0;
  FileMode := 0; // 0=Read, 1=Write, 2=Read/Write
  AssignFile(F, String(cFilePath));
  Try
    Reset(F);
    I := 0;
    While Not Eof(F) Do
    Begin
      SetLength(vDataArray, Length(vDataArray) + 1);
      ReadLn(F, vDataArray[I]);
      //ReadLn(F, S);
      //vDataArray[I] := PChar(S);
      Inc(I);
    End;
    CloseFile(F);
  Except
    CloseFile(F);
    Result := 1;
  End;
End;

Exports xLoadChecksumFile;
Exports xSaveChecksumFile;
Exports xGetStringArray;

Begin
End.

