{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{             Test Case for Caching Classes               }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2006 Zeos Development Group       }
{                                                         }
{ License Agreement:                                      }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ The source code of the ZEOS Libraries and packages are  }
{ distributed under the Library GNU General Public        }
{ License (see the file COPYING / COPYING.ZEOS)           }
{ with the following  modification:                       }
{ As a special exception, the copyright holders of this   }
{ library give you permission to link this library with   }
{ independent modules to produce an executable,           }
{ regardless of the license terms of these independent    }
{ modules, and to copy and distribute the resulting       }
{ executable under terms of your choice, provided that    }
{ you also meet, for each linked independent module,      }
{ the terms and conditions of the license of that module. }
{ An independent module is a module which is not derived  }
{ from or based on this library. If you modify this       }
{ library, you may extend this exception to your version  }
{ of the library, but you are not obligated to do so.     }
{ If you do not wish to do so, delete this exception      }
{ statement from your version.                            }
{                                                         }
{                                                         }
{ The project web site is located on:                     }
{   http://zeos.firmos.at  (FORUM)                        }
{   http://zeosbugs.firmos.at (BUGTRACKER)                }
{   svn://zeos.firmos.at/zeos/trunk (SVN Repository)      }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{   http://www.zeoslib.sourceforge.net                    }
{                                                         }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZTestDbcCache;

interface

{$I ZDbc.inc}

uses
{$IFDEF VER120BELOW}
  DateUtils,
{$ENDIF}
  Contnrs, {$IFDEF FPC}testregistry{$ELSE}TestFramework{$ENDIF},
  ZDbcCache, {$IFDEF OLDFPC}ZClasses,{$ENDIF} ZSysUtils,
  ZDbcIntfs, SysUtils, Classes, ZDbcResultSetMetadata,
  ZCompatibility, ZTestCase;

type

  {** Implements a test case for TZRowAccessor. }
  TZTestRowAccessorCase = class(TZGenericTestCase)
  private
    FRowAccessor: TZRowAccessor;
    FBoolean: Boolean;
    FByte: Byte;
    FShort: ShortInt;
    FSmall: SmallInt;
    FInt: Integer;
    FLong: LongInt;
    FFloat: Single;
    FDouble: Double;
    FBigDecimal: Int64;
    FString: string;
    FDate: TDateTime;
    FTime: TDateTime;
    FTimeStamp: TDateTime;
    FAsciiStream: TStream;
    FUnicodeStream: TStream;
    FBinaryStream: TStream;
    FByteArray: TBytes;
    FAsciiStreamData: Ansistring;
    FUnicodeStreamData: WideString;
    FBinaryStreamData: Pointer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;

    function GetColumnsInfo(Index: Integer; ColumnType: TZSqlType;
      Nullable: TZColumnNullableType; ReadOnly: Boolean;
      Writable: Boolean): TZColumnInfo;
    function GetColumnsInfoCollection: TObjectList;
    function GetRowAccessor: TZRowAccessor;
    function CompareArrays(Array1, Array2: TBytes): Boolean;
    procedure FillRowAccessor(RowAccessor: TZRowAccessor);
    function CompareStreams(Stream1: TStream; Stream2: TStream): Boolean; overload;

    property RowAccessor: TZRowAccessor read FRowAccessor write FRowAccessor;
  published
    procedure TestFillRowAccessor;
    procedure TestRowAccesorNull;
    procedure TestRowAccessorBoolean;
    procedure TestRowAccessorByte;
    procedure TestRowAccessorShort;
    procedure TestRowAccessorSmall;
    procedure TestRowAccessorInteger;
    procedure TestRowAccessorLong;
    procedure TestRowAccessorFloat;
    procedure TestRowAccessorDouble;
    procedure TestRowAccessorBigDecimal;
    procedure TestRowAccessorDate;
    procedure TestRowAccessorTime;
    procedure TestRowAccessorTimestamp;
    procedure TestRowAccessorString;
    procedure TestRowAccessor;
    procedure TestRowAccessorBytes;
    procedure TestRowAccesorBlob;
    procedure TestRowAccessorAsciiStream;
    procedure TestRowAccessorUnicodeStream;
    procedure TestRowAccessorBinaryStream;
    procedure TestRowAccessorReadonly;
  end;

implementation

uses ZTestConsts;

const
  stBooleanIndex        = {$IFDEF GENERIC_INDEX}0{$ELSE}1{$ENDIF};
  stByteIndex           = {$IFDEF GENERIC_INDEX}1{$ELSE}2{$ENDIF};
  stShortIndex          = {$IFDEF GENERIC_INDEX}2{$ELSE}3{$ENDIF};
  stSmallIndex          = {$IFDEF GENERIC_INDEX}3{$ELSE}4{$ENDIF};
  stIntegerIndex        = {$IFDEF GENERIC_INDEX}4{$ELSE}5{$ENDIF};
  stLongIndex           = {$IFDEF GENERIC_INDEX}5{$ELSE}6{$ENDIF};
  stFloatIndex          = {$IFDEF GENERIC_INDEX}6{$ELSE}7{$ENDIF};
  stDoubleIndex         = {$IFDEF GENERIC_INDEX}7{$ELSE}8{$ENDIF};
  stBigDecimalIndex     = {$IFDEF GENERIC_INDEX}8{$ELSE}9{$ENDIF};
  stStringIndex         = {$IFDEF GENERIC_INDEX}9{$ELSE}10{$ENDIF};
  stBytesIndex          = {$IFDEF GENERIC_INDEX}10{$ELSE}11{$ENDIF};
  stDateIndex           = {$IFDEF GENERIC_INDEX}11{$ELSE}12{$ENDIF};
  stTimeIndex           = {$IFDEF GENERIC_INDEX}12{$ELSE}13{$ENDIF};
  stTimestampIndex      = {$IFDEF GENERIC_INDEX}13{$ELSE}14{$ENDIF};
  stAsciiStreamIndex    = {$IFDEF GENERIC_INDEX}14{$ELSE}15{$ENDIF};
  stUnicodeStreamIndex  = {$IFDEF GENERIC_INDEX}15{$ELSE}16{$ENDIF};
  stBinaryStreamIndex   = {$IFDEF GENERIC_INDEX}16{$ELSE}17{$ENDIF};


{ TZTestRowAccessorCase }

{**
  Compares two byte arrays
  @param Array1 the first array to compare.
  @param Array2 the second array to compare.
  @return <code>True</code> if arrays are equal.
}
function TZTestRowAccessorCase.CompareArrays(Array1, Array2: TBytes):
  Boolean;
var
  I: Integer;
begin
  Result := False;
  if High(Array2) <> High(Array1) then Exit;
  for I := 0 to High(Array1) do
    if Array1[I] <> Array2[I] then Exit;
  Result := True;
end;

function TZTestRowAccessorCase.GetColumnsInfo(Index: Integer;
  ColumnType: TZSqlType; Nullable: TZColumnNullableType; ReadOnly: Boolean;
  Writable: Boolean): TZColumnInfo;
begin
  Result := TZColumnInfo.Create;

  Result.AutoIncrement := True;
  Result.CaseSensitive := True;
  Result.Searchable := True;
  Result.Currency := True;
  Result.Nullable := Nullable;
  Result.Signed := True;
  Result.ColumnDisplaySize := 32;
  Result.ColumnLabel := 'Test Labe'+IntToStr(Index);
  Result.ColumnName := 'TestName'+IntToStr(Index);
  Result.SchemaName := 'TestSchemaName';
  case ColumnType of
    stString: Result.Precision := 255;
    stBytes: Result.Precision := 5;
  else
    Result.Precision := 0;
  end;
  Result.Scale := 5;
  Result.TableName := 'TestTableName';
  Result.CatalogName := 'TestCatalogName';
  Result.ColumnType := ColumnType;
  Result.ReadOnly := ReadOnly;
  Result.Writable := Writable;
  Result.DefinitelyWritable := Writable;
end;

{**
  Create IZCollection and fill it by ZColumnInfo objects
  @return the ColumnInfo object
}
function TZTestRowAccessorCase.GetColumnsInfoCollection: TObjectList;
begin
  Result := TObjectList.Create;
  with Result do
  begin
    Add(GetColumnsInfo(stBooleanIndex, stBoolean, ntNullable, False, True));
    Add(GetColumnsInfo(stByteIndex, stByte, ntNullable, False, True));
    Add(GetColumnsInfo(stShortIndex, stShort, ntNullable, False, True));
    Add(GetColumnsInfo(stSmallIndex, stSmall, ntNullable, False, True));
    Add(GetColumnsInfo(stIntegerIndex, stInteger, ntNullable, False, True));
    Add(GetColumnsInfo(stLongIndex, stLong, ntNullable, False, True));
    Add(GetColumnsInfo(stFloatIndex, stFloat, ntNullable, False, True));
    Add(GetColumnsInfo(stDoubleIndex, stDouble, ntNullable, False, True));
    Add(GetColumnsInfo(stBigDecimalIndex, stBigDecimal, ntNullable, False, True));
    Add(GetColumnsInfo(stStringIndex, stString, ntNullable, False, True));
    Add(GetColumnsInfo(stBytesIndex, stBytes, ntNullable, False, True));
    Add(GetColumnsInfo(stDateIndex, stDate, ntNullable, False, True));
    Add(GetColumnsInfo(stTimeIndex, stTime, ntNullable, False, True));
    Add(GetColumnsInfo(stTimestampIndex, stTimestamp, ntNullable, False, True));
    Add(GetColumnsInfo(stAsciiStreamIndex, stAsciiStream, ntNullable, False, True));
    Add(GetColumnsInfo(stUnicodeStreamIndex, stUnicodeStream, ntNullable, False, True));
    Add(GetColumnsInfo(stBinaryStreamIndex, stBinaryStream, ntNullable, False, True));
  end;
end;

{**
  Create TZRowAccessor object and allocate it buffer
  @return the TZRowAccessor object
}
function TZTestRowAccessorCase.GetRowAccessor: TZRowAccessor;
var
  ColumnsInfo: TObjectList;
begin
  ColumnsInfo := GetColumnsInfoCollection;
  try
    Result := TZUnicodeRowAccessor.Create(ColumnsInfo, @ConSettingsDummy);  //dummy cp: Stringfield cp is inconsistent
    Result.Alloc;
  finally
    ColumnsInfo.Free;
  end;
end;

{**
  Setup paramters for test such as variables, stream datas and streams
}
procedure TZTestRowAccessorCase.SetUp;
var
  BufferChar: PAnsiChar;
  BufferWideChar: PWideChar;
begin
  FDate := SysUtils.Date;
  FTime := SysUtils.Time;
  FTimeStamp := SysUtils.Now;

  FAsciiStreamData := 'Test Ascii Stream Data';
  FAsciiStream := TMemoryStream.Create;
  BufferChar := PAnsiChar(FAsciiStreamData);
  FAsciiStream.Write(BufferChar^, Length(FAsciiStreamData));

  FUnicodeStreamData := 'Test Unicode Stream Data';
  FUnicodeStream := TMemoryStream.Create;
  BufferWideChar := PWideChar(FUnicodeStreamData);
  FUnicodeStream.Write(BufferWideChar^, Length(FUnicodeStreamData) * 2);

  FBinaryStream := TMemoryStream.Create;
  FBinaryStreamData := AllocMem(BINARY_BUFFER_SIZE);
  FillChar(FBinaryStreamData^, BINARY_BUFFER_SIZE, 55);
  FBinaryStream.Write(FBinaryStreamData^, BINARY_BUFFER_SIZE);

  FBoolean := true;
  FByte := 255;
  FShort := 127;
  FSmall := 32767;
  FInt := 2147483647;
  FLong := 1147483647;
  FFloat := 3.4E-38;
  FDouble := 1.7E-308;
  FBigDecimal := 9223372036854775807;
  FString := '0123456789';

  SetLength(FByteArray, 5);
  FByteArray[0] := 0;
  FByteArray[1] := 1;
  FByteArray[2] := 2;
  FByteArray[3] := 3;
  FByteArray[4] := 4;

  RowAccessor := GetRowAccessor;
  FillRowAccessor(RowAccessor);
end;

{**
  Free parameters for test such as stream datas and streams
}
procedure TZTestRowAccessorCase.TearDown;
begin
  RowAccessor.Dispose;
  RowAccessor.Free;
  RowAccessor := nil;

  FAsciiStream.Free;
  FUnicodeStream.Free;
  FBinaryStream.Free;
  FreeMem(FBinaryStreamData);
end;

{**
  Test for blob filed
}
procedure TZTestRowAccessorCase.TestRowAccesorBlob;
var
  Blob: IZBlob;
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
   Blob := GetBlob(stAsciiStreamIndex, WasNull{%H-});
   CheckNotNull(Blob, 'Not Null blob from asciistream field');
   Check(not Blob.IsEmpty, 'Blob from asciistream empty');
   Blob := nil;

   Blob := GetBlob(stUnicodeStreamIndex, WasNull);
   CheckNotNull(Blob, 'Not Null blob from unicodestream field');
   Check(not Blob.IsEmpty, 'Blob from unicodestream empty');
   Blob := nil;

   Blob := GetBlob(stAsciiStreamIndex, WasNull);
   CheckNotNull(Blob, 'Not Null blob from binarystream field');
   Check(not Blob.IsEmpty, 'Blob from binarystream empty');
   Blob := nil;
  end;
end;

{**
  Test for setup to null fields and check it on correspondence to null
}
procedure TZTestRowAccessorCase.TestRowAccesorNull;
begin
  with RowAccessor do
  begin
   Check(not IsNull(stBooleanIndex), 'Not Null boolen column');
   Check(not IsNull(stByteIndex), 'Not Null byte column');
   Check(not IsNull(stShortIndex), 'Not Null short column');
   Check(not IsNull(stSmallIndex), 'Not Null small column');
   Check(not IsNull(stIntegerIndex), 'Not Null integer column');
   Check(not IsNull(stLongIndex), 'Not Null longint column');
   Check(not IsNull(stFloatIndex), 'Not Null float column');
   Check(not IsNull(stDoubleIndex), 'Not Null double column');
   Check(not IsNull(stBigDecimalIndex), 'Not Null bigdecimal column');
   Check(not IsNull(stStringIndex), 'Not Null srting column');
   Check(not IsNull(stBytesIndex), 'Not Null bytearray column');
   Check(not IsNull(stDateIndex), 'Not Null date column');
   Check(not IsNull(stTimeIndex), 'Not Null time column');
   Check(not IsNull(stTimestampIndex), 'Not Null timestamp column');
   Check(not IsNull(stAsciiStreamIndex), 'Not Null aciistream column');
   Check(not IsNull(stUnicodeStreamIndex), 'Not Null unicodestream column');
   Check(not IsNull(stAsciiStreamIndex), 'Not Null binarystream column');

   try
     SetNull(stBooleanIndex);
   except
     Fail('Incorrect boolean method behavior');
   end;
   Check(IsNull(stBooleanIndex), 'Null boolean column');
   try
     SetNull(stByteIndex);
   except
     Fail('Incorrect byte method behavior');
   end;
   Check(IsNull(stByteIndex), 'Null byte column');
   try
     SetNull(stShortIndex);
   except
     Fail('Incorrect short method behavior');
   end;
   Check(IsNull(stShortIndex), 'Null short column');
   try
     SetNull(stSmallIndex);
   except
     Fail('Incorrect small method behavior');
   end;
   Check(IsNull(stSmallIndex), 'Null small column');
   try
     SetNull(stIntegerIndex);
   except
     Fail('Incorrect integer method behavior');
   end;
   Check(IsNull(stIntegerIndex), 'Null integer column');
   try
     SetNull(stLongIndex);
   except
     Fail('Incorrect longint method behavior');
   end;
   Check(IsNull(stLongIndex), 'Null longint column');
   try
     SetNull(stFloatIndex);
   except
     Fail('Incorrect float method behavior');
   end;
   Check(IsNull(stFloatIndex), 'Null float column');
   try
     SetNull(stDoubleIndex);
   except
     Fail('Incorrect double method behavior');
   end;
   Check(IsNull(stDoubleIndex), 'Null double column');
   try
     SetNull(stStringIndex);
   except
     Fail('Incorrect bigdecimal method behavior');
   end;
   Check(IsNull(stStringIndex), 'Null bigdecimal column');
   try
     SetNull(stBytesIndex);
   except
     Fail('Incorrect string method behavior');
   end;
   Check(IsNull(stBytesIndex), 'Null string column');
   try
     SetNull(stDateIndex);
   except
   Fail('Incorrect bytearray method behavior');
   end;
   Check(IsNull(stDateIndex), 'Null bytearray column');
   try
     SetNull(stTimeIndex);
   except
     Fail('Incorrect date method behavior');
   end;
   Check(IsNull(stTimeIndex), 'Null date column');
   try
     SetNull(stTimestampIndex);
   except
   Fail('Incorrect time method behavior');
   end;
   Check(IsNull(stTimestampIndex), 'Null time column');
   try
     SetNull(stAsciiStreamIndex);
   except
     Fail('Incorrect timestamp method behavior');
   end;
   Check(IsNull(stAsciiStreamIndex), 'Null timestamp column');
   try
     SetNull(stUnicodeStreamIndex);
   except
     Fail('Incorrect asciisreeam method behavior');
   end;
   Check(IsNull(stUnicodeStreamIndex), 'Null asciisreeam column');
   try
     SetNull(stAsciiStreamIndex);
   except
     Fail('Incorrect unicodestream method behavior');
   end;
   Check(IsNull(stAsciiStreamIndex), 'Null unicodestream column');
   try
   SetNull(stAsciiStreamIndex);
   except
     Fail('Incorrect bytestream method behavior');
   end;
   Check(IsNull(stAsciiStreamIndex), 'Null bytestream column');
   try
     SetBinaryStream(stAsciiStreamIndex, FBinaryStream);
   except
     Fail('Incorrect SetBinaryStream method behavior');
   end;
  end;
end;

{**
  Test for general TestZRowAccessor functions
}
procedure TZTestRowAccessorCase.TestRowAccessor;
var
  RowBuffer1: PZRowBuffer;
  RowBuffer2: PZRowBuffer;
begin
  {$IFNDEF NO_COLUMN_LIMIT}
  RowBuffer1 := AllocMem(RowAccessor.RowSize);
  RowBuffer2 := AllocMem(RowAccessor.RowSize);
  {$ELSE}
  RowBuffer1 := RowAccessor.AllocBuffer(RowBuffer1);
  RowBuffer2 := RowAccessor.AllocBuffer(RowBuffer2);
  {$ENDIF}
  RowAccessor.InitBuffer(RowBuffer1);
  RowAccessor.InitBuffer(RowBuffer2);

  RowBuffer1^.Index := 100;
  RowBuffer1^.UpdateType := utModified;
  RowBuffer1^.BookmarkFlag := 2;

  with RowAccessor do
  begin
   {check Copy method}
    try
      RowAccessor.CopyBuffer(RowBuffer1, RowBuffer2);
    except
      Fail('Incorrect Copy method behavior');
    end;
    Check(Assigned(RowBuffer2),'Copy. The RowBuffer2 assigned )');
    CheckEquals(100, RowBuffer2^.Index, 'Copy. Buffer2 Index');
    CheckEquals(ord(utModified), ord(RowBuffer2^.UpdateType),
        'Copy. Buffer2 UpdateType');
    CheckEquals(2, RowBuffer2^.BookmarkFlag, 'Copy. Buffer2 BookmarkFlag');

    {check CopyTo method}
    try
      RowAccessor.CopyTo(RowBuffer1);
    except
      Fail('Incorrect CopyTo method behavior');
    end;
    Check(Assigned(RowBuffer1),'CopyTo. The RowBuffer1 assigned )');
    CheckEquals(stStringIndex, RowBuffer1^.Index, 'CopyTo. The RowBuffer1 Index');
    CheckEquals(ord(utInserted), ord(RowBuffer1^.UpdateType),
        'CopyTo. The RowBuffer1 UpdateType');
    CheckEquals(1, RowBuffer1^.BookmarkFlag,
        'CopyTo. The RowBuffer1 BookmarkFlag');

    {check Clear method}
    try
      RowAccessor.ClearBuffer(RowBuffer1);
    except
       Fail('Incorrect CopyTo method behavior');
    end;
    Check(Assigned(RowBuffer1),'Clear. The RowBuffer1 assigned )');
    CheckNotEquals(stStringIndex, RowBuffer1^.Index, 'Clear. The RowBuffer1 Index');
    CheckNotEquals(ord(utInserted), ord(RowBuffer1^.UpdateType),
        'Clear. The RowBuffer1 UpdateType');
    CheckNotEquals(1, RowBuffer1^.BookmarkFlag,
        'Clear. The RowBuffer1 BookmarkFlag');

    {check Moveto method}
    try
      RowAccessor.MoveTo(RowBuffer1);
    except
      Fail('Incorrect CopyTo method behavior');
    end;
    Check(Assigned(RowBuffer1), 'MoveTo. The RowBuffer1 assigned');
    Check(Assigned(RowBuffer1),'MoveTo. The RowBuffer1 assigned )');
    CheckEquals(stStringIndex, RowBuffer1^.Index, 'MoveTo. The RowBuffer1 Index');
    CheckEquals(ord(utInserted), ord(RowBuffer1^.UpdateType),
        'MoveTo. The RowBuffer1 UpdateType');
    CheckEquals(1, RowBuffer1^.BookmarkFlag,
        'MoveTo. The RowBuffer1 BookmarkFlag');

    CheckNotEquals(stStringIndex, RowBuffer^.Index, 'MoveTo. The RowBuffer Index');
    CheckNotEquals(ord(utInserted), ord(RowBuffer^.UpdateType),
        'MoveTo. The RowBuffer UpdateType');
    CheckNotEquals(1, RowBuffer^.BookmarkFlag,
        'MoveTo. The RowBuffer BookmarkFlag');

    {check CopyFrom method}
    try
      RowAccessor.CopyFrom(RowBuffer2);
    except
      Fail('Incorrect CopyTo method behavior');
    end;
    CheckEquals(100, RowBuffer^.Index, 'CopyFrom. The RowBuffer2 Index');
    CheckEquals(ord(utModified), ord(RowBuffer^.UpdateType),
        'CopyFrom. The RowBuffer2 UpdateType');
    CheckEquals(2, RowBuffer^.BookmarkFlag,
        'CopyFrom. The RowBuffer2 BookmarkFlag');

    {check Clear method}
    try
      RowAccessor.Clear;
    except
      Fail('Incorrect Clear method behavior');
    end;
    Check(Assigned(RowAccessor.RowBuffer), 'Clear. The RowBuffer assigned');
    CheckNotEquals(stStringIndex, RowBuffer^.Index, 'Clear. The RowBuffer Index');
    CheckNotEquals(ord(utInserted), ord(RowBuffer^.UpdateType),
        'Clear. The RowBuffer UpdateType');
    CheckNotEquals(1, RowBuffer^.BookmarkFlag,
        'Clear. The RowBuffer BookmarkFlag');

    {check  dispose}
    try
      RowAccessor.Dispose;
    except
      Fail('Incorrect Dispose method behavior');
    end;
    Check(not Assigned(RowAccessor.RowBuffer), 'The not RowAccessor.RowBuffer assigned');
  end;

  RowAccessor.DisposeBuffer(RowBuffer1);
  RowAccessor.DisposeBuffer(RowBuffer2);
end;

procedure TZTestRowAccessorCase.TestRowAccessorAsciiStream;
var
  Stream: TStream;
  ReadNum: Integer;
  BufferChar: array[0..100] of AnsiChar;
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    try
      Stream := GetAsciiStream(stAsciiStreamIndex, WasNull{%H-});
      CheckNotNull(Stream, 'AsciiStream');
      Check(CompareStreams(Stream, FAsciiStream), 'AsciiStream');
      Stream.Position := 0;
      ReadNum := Stream.Read(BufferChar{%H-}, 101);
      Stream.Free;
      CheckEquals(String(FAsciiStreamData), BufferToStr(BufferChar, ReadNum));
    except
      Fail('Incorrect GetAsciiStream method behavior');
    end;
  end;
end;

{**
  Test for BigDecimal field
}
procedure TZTestRowAccessorCase.TestRowAccessorBigDecimal;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(True, GetBoolean(stBigDecimalIndex, WasNull{%H-}), 'GetBoolean');
    CheckEquals(Byte(FBigDecimal), GetByte(stBigDecimalIndex, WasNull), 0, 'GetByte');
    CheckEquals(ShortInt(FBigDecimal), GetShort(stBigDecimalIndex, WasNull), 0, 'GetShort');
    CheckEquals(SmallInt(FBigDecimal), GetSmall(stBigDecimalIndex, WasNull), 0, 'GetSmall');
    CheckEquals(Integer(FBigDecimal), GetInt(stBigDecimalIndex, WasNull), 0, 'GetInt');
{$IFNDEF VER130BELOW}
    CheckEquals(Int64(FBigDecimal), GetLong(stBigDecimalIndex, WasNull), 0, 'GetLong');
{$ENDIF}
//    CheckEquals(FBigDecimal, GetFloat(stDoubleIndex, WasNull), 0.001, 'GetFloat');
//    CheckEquals(FBigDecimal, GetDouble(stDoubleIndex, WasNull), 0.001, 'GetDouble');
    CheckEquals(FBigDecimal, GetBigDecimal(stBigDecimalIndex, WasNull), 0.001, 'GetBigDecimal');
    CheckEquals(FloatToSQLStr(FBigDecimal), GetString(stBigDecimalIndex, WasNull), 'GetString');
  end;
end;

{**
  Test for BinaryStream field
}
procedure TZTestRowAccessorCase.TestRowAccessorBinaryStream;
var
  Stream: TStream;
  ReadNum: Integer;
  Buffer: array[0..BINARY_BUFFER_SIZE] of Byte;
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    try
      Stream := GetBinaryStream(stBinaryStreamIndex, WasNull{%H-});
      CheckNotNull(Stream, 'BinaryStream');
      Check(CompareStreams(Stream, FBinaryStream), 'BinaryStream');
      Stream.Position := 0;
      ReadNum := Stream.Read(Buffer{%H-}, BINARY_BUFFER_SIZE);
      Stream.Free;
      CheckEquals(ReadNum, BINARY_BUFFER_SIZE);
      Check(CompareMem(@Buffer, FBinaryStreamData, BINARY_BUFFER_SIZE));
    except
      Fail('Incorrect GetBinaryStream method behavior');
    end;
  end;
end;

{**
  Test for Boolean field
}
procedure TZTestRowAccessorCase.TestRowAccessorBoolean;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(True, GetBoolean(stBooleanIndex, WasNull{%H-}), 'GetBoolean');
    CheckEquals(1, GetByte(stBooleanIndex, WasNull), 0, 'GetByte');
    CheckEquals(1, GetShort(stBooleanIndex, WasNull), 0, 'GetShort');
    CheckEquals(1, GetSmall(stBooleanIndex, WasNull), 0, 'GetSmall');
    CheckEquals(1, GetInt(stBooleanIndex, WasNull), 0, 'GetInt');
    CheckEquals(1, GetLong(stBooleanIndex, WasNull), 0, 'GetLong');
    CheckEquals(1, GetFloat(stBooleanIndex, WasNull), 0, 'GetFloat');
    CheckEquals(1, GetDouble(stBooleanIndex, WasNull), 0, 'GetDouble');
    CheckEquals(1, GetBigDecimal(stBooleanIndex, WasNull), 0, 'GetBigDecimal');
    CheckEquals('True', GetString(stBooleanIndex, WasNull), 'GetString');
  end;
end;

{**
  Test for Byte field
}
procedure TZTestRowAccessorCase.TestRowAccessorByte;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(True, GetBoolean(stByteIndex, WasNull{%H-}), 'GetBoolean');
    CheckEquals(FByte, GetByte(stByteIndex, WasNull), 0, 'GetByte');
    CheckEquals(ShortInt(FByte), GetShort(stByteIndex, WasNull), 0, 'GetShort');
    CheckEquals(SmallInt(FByte), GetSmall(stByteIndex, WasNull), 0, 'GetSmall');
    CheckEquals(FByte, GetInt(stByteIndex, WasNull), 0, 'GetInt');
    CheckEquals(FByte, GetLong(stByteIndex, WasNull), 0, 'GetLong');
    CheckEquals(FByte, GetFloat(stByteIndex, WasNull), 0, 'GetFloat');
    CheckEquals(FByte, GetDouble(stByteIndex, WasNull), 0, 'GetDouble');
    CheckEquals(FByte, GetBigDecimal(stByteIndex, WasNull), 0, 'GetBigDecimal');
    CheckEquals(IntToStr(FByte), GetString(stByteIndex, WasNull), 'GetString');
  end;
end;

{**
  Test for Bytes field
}
procedure TZTestRowAccessorCase.TestRowAccessorBytes;

  function  ArrayToString(BytesArray: TBytes): string;
  var
    I: Integer;
  begin
    for I := 0 to High(BytesArray) do
       Result := Result + Char(BytesArray[I]);
  end;

var
  I: Integer;
  ByteArray: TBytes;
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    ByteArray := GetBytes(stBytesIndex, WasNull{%H-});
    CheckNotEquals(0, High(ByteArray));
    CheckEquals(ArrayToString(FByteArray), GetString(stBytesIndex, WasNull),
      'strings from bytearray equals');

    if High(ByteArray) <> High(FByteArray) then
      Fail('Size two array diffrent');
    for I := 0 to High(ByteArray) do
      if ByteArray[I] <> FByteArray[I] then
        Fail('Array have different values');
  end;
end;

{**
  Test for Date field
}
procedure TZTestRowAccessorCase.TestRowAccessorDate;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(FDate, AnsiSqlDateToDateTime(GetString(stDateIndex, WasNull{%H-})), 0);
    CheckEquals(FDate, GetDate(stDateIndex, WasNull), 0);
    CheckEquals(FDate, GetTimestamp(stDateIndex, WasNull), 0);
  end;
end;

{**
  Test for Double field
}
procedure TZTestRowAccessorCase.TestRowAccessorDouble;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(True, GetBoolean(stDoubleIndex, WasNull{%H-}), 'GetBoolean');
    CheckEquals(Byte(Trunc(FDouble)), GetByte(stDoubleIndex, WasNull), 0, 'GetByte');
    CheckEquals(Trunc(FDouble), GetShort(stDoubleIndex, WasNull), 0, 'GetShort');
    CheckEquals(Trunc(FDouble), GetSmall(stDoubleIndex, WasNull), 0, 'GetSmall');
    CheckEquals(Trunc(FDouble), GetInt(stDoubleIndex, WasNull), 0, 'GetInt');
    CheckEquals(Trunc(FDouble), GetLong(stDoubleIndex, WasNull), 0, 'GetLong');
    CheckEquals(FDouble, GetFloat(stDoubleIndex, WasNull), 0.001, 'GetFloat');
    CheckEquals(FDouble, GetDouble(stDoubleIndex, WasNull), 0.001, 'GetDouble');
    CheckEquals(FDouble, GetBigDecimal(stDoubleIndex, WasNull), 0.001, 'GetBigDecimal');
    CheckEquals(FloatToSQLStr(FDouble), GetString(stDoubleIndex, WasNull), 'GetString');
  end;
end;

{**
  Test for fill all fileds by their values
}
procedure TZTestRowAccessorCase.TestFillRowAccessor;
var
  RowAccessor: TZRowAccessor;
begin
  RowAccessor := GetRowAccessor;
  FillRowAccessor(RowAccessor);
  RowAccessor.Dispose;
  RowAccessor.Free;
end;

{**
  Test for Float field
}
procedure TZTestRowAccessorCase.TestRowAccessorFloat;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(True, GetBoolean(stFloatIndex, WasNull{%H-}), 'GetBoolean');
    CheckEquals(Trunc(FFloat), GetByte(stFloatIndex, WasNull), 0, 'GetByte');
    CheckEquals(Trunc(FFloat), GetShort(stFloatIndex, WasNull), 0, 'GetShort');
    CheckEquals(Trunc(FFloat), GetSmall(stFloatIndex, WasNull), 0, 'GetSmall');
    CheckEquals(Trunc(FFloat), GetInt(stFloatIndex, WasNull), 0, 'GetInt');
    CheckEquals(Trunc(FFloat), GetLong(stFloatIndex, WasNull), 0, 'GetLong');
    CheckEquals(FFloat, GetFloat(stFloatIndex, WasNull), 0.001, 'GetFloat');
    CheckEquals(FFloat, GetDouble(stFloatIndex, WasNull), 0.001, 'GetDouble');
    CheckEquals(FFloat, GetBigDecimal(stFloatIndex, WasNull), 0.001, 'GetBigDecimal');
    CheckEquals(FloatToSQLStr(FFloat), GetString(stFloatIndex, WasNull), 'GetString');
  end;
end;

{**
  Test for Integer field
}
procedure TZTestRowAccessorCase.TestRowAccessorInteger;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(True, GetBoolean(stIntegerIndex, WasNull{%H-}), 'GetBoolean');
    CheckEquals(Byte(FInt), GetByte(stIntegerIndex, WasNull), 0, 'GetByte');
    CheckEquals(ShortInt(FInt), GetShort(stIntegerIndex, WasNull), 0, 'GetShort');
    CheckEquals(SmallInt(FInt), GetSmall(stIntegerIndex, WasNull), 0, 'GetSmall');
    CheckEquals(FInt, GetInt(stIntegerIndex, WasNull), 0, 'GetInt');
    CheckEquals(FInt, GetLong(stIntegerIndex, WasNull), 0, 'GetLong');
    CheckEquals(FInt, GetFloat(stIntegerIndex, WasNull), 1, 'GetFloat');
    CheckEquals(FInt, GetDouble(stIntegerIndex, WasNull), 0, 'GetDouble');
    CheckEquals(FInt, GetBigDecimal(stIntegerIndex, WasNull), 0, 'GetBigDecimal');
    CheckEquals(IntToStr(FInt), GetString(stIntegerIndex, WasNull), 'GetString');
  end;
end;

{**
  Test for Long field
}
procedure TZTestRowAccessorCase.TestRowAccessorLong;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(True, GetBoolean(stLongIndex, WasNull{%H-}), 'GetBoolean');
    CheckEquals(Byte(FLong), GetByte(stLongIndex, WasNull), 0, 'GetByte');
    CheckEquals(ShortInt(FLong), GetShort(stLongIndex, WasNull), 0, 'GetShort');
    CheckEquals(SmallInt(FLong), GetSmall(stLongIndex, WasNull), 0, 'GetSmall');
    CheckEquals(FLong, GetInt(stLongIndex, WasNull), 0, 'GetInt');
    CheckEquals(FLong, GetLong(stLongIndex, WasNull), 0, 'GetLong');
    CheckEquals(FLong, GetFloat(stLongIndex, WasNull), 1, 'GetFloat');
    CheckEquals(FLong, GetDouble(stLongIndex, WasNull), 0, 'GetDouble');
    CheckEquals(FLong, GetBigDecimal(stLongIndex, WasNull), 0, 'GetBigDecimal');
    CheckEquals(IntToStr(FLong), GetString(stLongIndex, WasNull), 'GetString');
  end;
end;

{**
  Test for Short field
}
procedure TZTestRowAccessorCase.TestRowAccessorReadonly;
var
  Collection: TObjectList;
  RowAccessor: TZRowAccessor;
begin
  Collection := GetColumnsInfoCollection;
  try
    RowAccessor := TZUnicodeRowAccessor.Create(Collection, @ConSettingsDummy); //dummy cp: Stringfield cp is inconsistent
    try
      RowAccessor.Dispose;
    finally
      RowAccessor.Free;
    end;
  finally
    Collection.Free;
  end;
end;

procedure TZTestRowAccessorCase.TestRowAccessorShort;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(True, GetBoolean(stShortIndex, WasNull{%H-}), 'GetBoolean');
    CheckEquals(Byte(FShort), GetByte(stShortIndex, WasNull), 0, 'GetByte');
    CheckEquals(ShortInt(FShort), GetShort(stShortIndex, WasNull), 0, 'GetShort');
    CheckEquals(SmallInt(FShort), GetSmall(stShortIndex, WasNull), 0, 'GetSmall');
    CheckEquals(FShort, GetInt(stShortIndex, WasNull), 0, 'GetInt');
    CheckEquals(FShort, GetLong(stShortIndex, WasNull), 0, 'GetLong');
    CheckEquals(FShort, GetFloat(stShortIndex, WasNull), 0, 'GetFloat');
    CheckEquals(FShort, GetDouble(stShortIndex, WasNull), 0, 'GetDouble');
    CheckEquals(FShort, GetBigDecimal(stShortIndex, WasNull), 0, 'GetBigDecimal');
    CheckEquals(IntToStr(FShort), GetString(stShortIndex, WasNull), 'GetString');
  end;
end;

procedure TZTestRowAccessorCase.TestRowAccessorSmall;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(True, GetBoolean(stSmallIndex, WasNull{%H-}), 'GetBoolean');
    CheckEquals(Byte(FSmall), GetByte(stSmallIndex, WasNull), 0, 'GetByte');
    CheckEquals(ShortInt(FSmall), GetShort(stSmallIndex, WasNull), 0, 'GetShort');
    CheckEquals(FSmall, GetSmall(stSmallIndex, WasNull), 0, 'GetSmall');
    CheckEquals(FSmall, GetInt(stSmallIndex, WasNull), 0, 'GetInt');
    CheckEquals(FSmall, GetLong(stSmallIndex, WasNull), 0, 'GetLong');
    CheckEquals(FSmall, GetFloat(stSmallIndex, WasNull), 0, 'GetFloat');
    CheckEquals(FSmall, GetDouble(stSmallIndex, WasNull), 0, 'GetDouble');
    CheckEquals(FSmall, GetBigDecimal(stSmallIndex, WasNull), 0, 'GetBigDecimal');
    CheckEquals(IntToStr(FSmall), GetString(stSmallIndex, WasNull), 'GetString');
  end;
end;

{**
  Test for String field
}
procedure TZTestRowAccessorCase.TestRowAccessorString;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(False, GetBoolean(stStringIndex, WasNull{%H-}), 'GetBoolean');
    CheckEquals(ShortInt(StrToIntDef(FString, 0)), GetByte(stStringIndex, WasNull), 0, 'GetByte');
    CheckEquals(SmallInt(StrToIntDef(FString, 0)), GetSmall(stStringIndex, WasNull), 0, 'GetSmall');
    CheckEquals(Integer(StrToIntDef(FString, 0)), GetInt(stStringIndex, WasNull), 0, 'GetInt');
    CheckEquals(LongInt(StrToIntDef(FString, 0)), GetLong(stStringIndex, WasNull), 0, 'GetLong');
    CheckEquals(StrToFloatDef(FString, 0), GetFloat(stStringIndex, WasNull), 100, 'GetFloat');
    CheckEquals(StrToFloatDef(FString, 0), GetDouble(stStringIndex, WasNull), 0, 'GetDouble');
    CheckEquals(Int64(StrToInt(FString)), GetBigDecimal(stStringIndex, WasNull), 0, 'GetBigDecimal');
    CheckEquals(FString, GetString(stStringIndex, WasNull), 'GetString');
{    Check(ArraysComapre(GetByteArrayFromString(FString),
       GetBytes(stStringIndex, WasNull)));}

    {test time convertion}
    SetString(stStringIndex, '1999-01-02 12:01:02');
    CheckEquals(EncodeDate(1999, 01, 02), GetDate(stStringIndex, WasNull), 0, 'GetDate');
    CheckEquals(EncodeTime(12, 01, 02, 0), GetTime(stStringIndex, WasNull), stShortIndex, 'GetTime');
    CheckEquals(EncodeDate(1999, 01, 02)+EncodeTime(12,01,02, 0),
      GetTimestamp(stStringIndex, WasNull), stShortIndex, 'GetTimestamp');
    SetString(stStringIndex, FString);
  end;
end;

{**
  Test for Time field
}
procedure TZTestRowAccessorCase.TestRowAccessorTime;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(FTime, AnsiSqlDateToDateTime(GetString(stTimeIndex, WasNull{%H-})), 3, 'GetString');
    CheckEquals(FTime, GetTime(stTimeIndex, WasNull), 3, 'Getime');
//    CheckEquals(FTime, GetTimestamp(stTimeIndex, WasNull), 3, 'GetTimestamp');
  end;
end;

{**
  Test for Timestamp field
}
procedure TZTestRowAccessorCase.TestRowAccessorTimestamp;
var
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    CheckEquals(FormatDateTime('yyyy-mm-dd hh:mm:ss', FTimeStamp),
        GetString(stTimestampIndex, WasNull{%H-}), 'GetString');
//!!! Rwrite    CheckEquals(DateOf(FTimeStamp), GetDate(stTimestampIndex, WasNull), 3, 'GetDate');
    CheckEquals(FTimeStamp, GetTimestamp(stTimestampIndex, WasNull), 3, 'GetTimestamp');
  end;
end;

{**
  Test for UnicodeStream field
}
procedure TZTestRowAccessorCase.TestRowAccessorUnicodeStream;
var
  Stream: TStream;
  ReadNum: Integer;
  BufferWideChar: array[0..100] of Char;
  ResultString: string;
  WasNull: Boolean;
begin
  with RowAccessor do
  begin
    try
      Stream := GetUnicodeStream(stUnicodeStreamIndex, WasNull{%H-});
      CheckNotNull(Stream, 'UnicodeStream');
      Check(CompareStreams(Stream, FUnicodeStream), 'UnicodeStream');
      Stream.Position := 0;
      ReadNum := Stream.Read(BufferWideChar{%H-}, 100);
      Stream.Free;
      ResultString := WideCharLenToString(@BufferWideChar, ReadNum div 2);
      CheckEquals(FUnicodeStreamData, ResultString);
    except
      Fail('Incorrect GetUnicodeStream method behavior');
    end;
  end;
end;

{**
  Fill fields by it values
}
procedure TZTestRowAccessorCase.FillRowAccessor(RowAccessor: TZRowAccessor);
begin
  with RowAccessor do
  begin
    try
      SetBoolean(stBooleanIndex, true);
      Check(not IsNull(stBooleanIndex));
    except
      Fail('Incorrect SetBoolean method behavior');
    end;
    try
      SetByte(stByteIndex, FByte);
    except
      Fail('Incorrect SetByte method behavior');
    end;
    try
      SetShort(stShortIndex, FShort);
    except
      Fail('Incorrect SetShort method behavior');
    end;
    try
      SetSmall(stSmallIndex, FSmall);
    except
      Fail('Incorrect SetSmall method behavior');
    end;
    try
      SetInt(stIntegerIndex, FInt);
    except
      Fail('Incorrect SetInt method behavior');
    end;
    try
      SetLong(stLongIndex, FLong);
    except
      Fail('Incorrect SetLong method behavior');
    end;
    try
      SetFloat(stFloatIndex, FFloat);
    except
      Fail('Incorrect SetFloat method behavior');
    end;
    try
      SetDouble(stDoubleIndex, FDouble);
    except
      Fail('Incorrect SetDouble method behavior');
    end;
    try
      SetBigDecimal(stBigDecimalIndex, FBigDecimal);
    except
      Fail('Incorrect SetBigDecimal method behavior');
    end;
    try
      SetString(stStringIndex, FString);
    except
      Fail('Incorrect SetString method behavior');
    end;
    try
      SetBytes(stBytesIndex, FByteArray);
    except
      Fail('Incorrect SetBytes method behavior');
    end;
    try
      SetDate(stDateIndex, FDate);
    except
      Fail('Incorrect SetDate method behavior');
    end;
    try
      SetTime(stTimeIndex, FTime);
    except
      Fail('Incorrect SetTime method behavior');
    end;
    try
      SetTimestamp(stTimestampIndex, FTimeStamp);
    except
      Fail('Incorrect SetTimestamp method behavior');
    end;
    try
      SetAsciiStream(stAsciiStreamIndex, FAsciiStream);
    except
      Fail('Incorrect SetAsciiStream method behavior');
    end;
    try
      SetUnicodeStream(stUnicodeStreamIndex, FUnicodeStream);
    except
      Fail('Incorrect SetUnicodeStream method behavior');
    end;
    try
      SetBinaryStream(stBinaryStreamIndex, FBinaryStream);
    except
      Fail('Incorrect SetBinaryStream method behavior');
    end;
    RowBuffer^.Index := stStringIndex;
    RowBuffer^.UpdateType := utInserted;
    RowBuffer^.BookmarkFlag := 1;
  end;
end;

function TZTestRowAccessorCase.CompareStreams(Stream1, Stream2: TStream):
  Boolean;
var
  Buffer1, Buffer2: array[0..1024] of Char;
  ReadNum1, ReadNum2: Integer;
begin
  CheckNotNull(Stream1, 'Stream #1 is null');
  CheckNotNull(Stream2, 'Stream #2 is null');
  CheckEquals(Stream1.Size, Stream2.Size, 'Stream sizes are not equal');

  Stream1.Position := 0;
  ReadNum1 := Stream1.Read(Buffer1{%H-}, 1024);
  Stream2.Position := 0;
  ReadNum2 := Stream2.Read(Buffer2{%H-}, 1024);

  CheckEquals(ReadNum1, ReadNum2, 'Read sizes are not equal.');
  Result := CompareMem(@Buffer1, @Buffer2, ReadNum1);
end;

initialization
  RegisterTest('dbc',TZTestRowAccessorCase.Suite);
end.

