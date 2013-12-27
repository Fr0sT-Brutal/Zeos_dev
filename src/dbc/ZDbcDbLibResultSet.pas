{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{         DBLib Resultset common functionality            }
{                                                         }
{        Originally written by Janos Fegyverneki          }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2012 Zeos Development Group       }
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
{   http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER)}
{   svn://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcDbLibResultSet;

interface

{$I ZDbc.inc}

uses
{$IFNDEF FPC}
  DateUtils,
{$ENDIF}
  {$IFDEF WITH_TOBJECTLIST_INLINE}System.Types, System.Contnrs{$ELSE}Types{$ENDIF},
  Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils,
  ZDbcIntfs, ZDbcResultSet, ZCompatibility, ZDbcResultsetMetadata,
  ZDbcGenericResolver, ZDbcCachedResultSet, ZDbcCache, ZDbcDBLib,
  ZPlainDbLibConstants, ZPlainDBLibDriver;

type
  {** Implements DBLib ResultSet. }
  TZDBLibResultSet = class(TZAbstractResultSet)
  private
    FSQL: string;
    FHandle: PDBPROCESS;
    DBLibColTypeCache: TSmallIntDynArray;
    DBLibColumnCount: Integer;
    procedure CheckColumnIndex(ColumnIndex: Integer);
  protected
    FDBLibConnection: IZDBLibConnection;
    FPlainDriver: IZDBLibPlainDriver;
    procedure Open; override;
    function InternalGetString(ColumnIndex: Integer): RawByteString; override;
  public
    constructor Create(Statement: IZStatement; SQL: string);
    destructor Destroy; override;

    procedure Close; override;

    function IsNull(ColumnIndex: Integer): Boolean; override;
    function GetAnsiRec(ColumnIndex: Integer): TZAnsiRec; override;
    function GetString(ColumnIndex: Integer): String; override;
    function GetAnsiString(ColumnIndex: Integer): AnsiString; override;
    function GetUTF8String(ColumnIndex: Integer): UTF8String; override;
    function GetUnicodeString(ColumnIndex: Integer): ZWideString; override;
    function GetBoolean(ColumnIndex: Integer): Boolean; override;
    function GetByte(ColumnIndex: Integer): Byte; override;
    function GetSmall(ColumnIndex: Integer): SmallInt; override;
    function GetInt(ColumnIndex: Integer): Integer; override;
    function GetLong(ColumnIndex: Integer): Int64; override;
    function GetFloat(ColumnIndex: Integer): Single; override;
    function GetDouble(ColumnIndex: Integer): Double; override;
    function GetBigDecimal(ColumnIndex: Integer): Extended; override;
    function GetBytes(ColumnIndex: Integer): TBytes; override;
    function GetDate(ColumnIndex: Integer): TDateTime; override;
    function GetTime(ColumnIndex: Integer): TDateTime; override;
    function GetTimestamp(ColumnIndex: Integer): TDateTime; override;
    function GetBlob(ColumnIndex: Integer): IZBlob; override;

    function Next: Boolean; override;
  end;

  {** Implements a cached resolver with mssql and sybase specific functionality. }
  TZDBLibCachedResolver = class (TZGenericCachedResolver, IZCachedResolver)
  private
    FAutoColumnIndex: Integer;
  public
    constructor Create(Statement: IZStatement; Metadata: IZResultSetMetadata);

    procedure PostUpdates(Sender: IZCachedResultSet; UpdateType: TZRowUpdateType;
      OldRowAccessor, NewRowAccessor: TZRowAccessor); override;
  end;

implementation

uses ZMessages, ZDbcLogging, ZDbcDBLibUtils, ZEncoding, ZSysUtils
  {$IFDEF WITH_UNITANSISTRINGS}, AnsiStrings{$ENDIF}
  {$IFDEF WITH_WIDESTRUTILS}, WideStrUtils {$ENDIF}
;

{ TZDBLibResultSet }

{**
  Constructs this object, assignes main properties and
  opens the record set.
  @param Statement a related SQL statement object.
  @param Handle a DBLib specific query handle.
}
constructor TZDBLibResultSet.Create(Statement: IZStatement; SQL: string);
begin
  inherited Create(Statement, SQL, nil, Statement.GetConnection.GetConSettings);
  Statement.GetConnection.QueryInterface(IZDBLibConnection, FDBLibConnection);
  FPlainDriver := FDBLibConnection.GetPlainDriver;
  FHandle := FDBLibConnection.GetConnectionHandle;
  FSQL := SQL;

  Open;
end;

{**
  Destroys this object and cleanups the memory.
}
destructor TZDBLibResultSet.Destroy;
begin
{ TODO -ofjanos -cGeneral : Does it need close here? }
  Close;
  inherited Destroy;
end;

{**
  Opens this recordset.
}
procedure TZDBLibResultSet.Open;
var
  I: Integer;
  ColumnInfo: TZColumnInfo;
  ColName: string;
  ColType: Integer;
begin
//Check if the current statement can return rows
  if FPlainDriver.dbCmdRow(FHandle) <> DBSUCCEED then
    raise EZSQLException.Create(SCanNotRetrieveResultSetData);

  { Fills the column info }
  ColumnsInfo.Clear;
  DBLibColumnCount := FPlainDriver.dbnumcols(FHandle);
  SetLength(DBLibColTypeCache, DBLibColumnCount + 1);
  for I := 1 to DBLibColumnCount do
  begin
    ColName := ConSettings^.ConvFuncs.ZRawToString(FPlainDriver.dbColName(FHandle, I),
      ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP);
    ColType := FPlainDriver.dbColtype(FHandle, I);
    ColumnInfo := TZColumnInfo.Create;

    ColumnInfo.ColumnLabel := ColName;
    ColumnInfo.ColumnName := ColName;
    if Self.FDBLibConnection.FreeTDS then
      ColumnInfo.ColumnType := ConvertFreeTDSToSqlType(ColType, ConSettings.CPType)
    else
      ColumnInfo.ColumnType := ConvertDBLibToSqlType(ColType, ConSettings.CPType);
    ColumnInfo.Currency := (ColType = FPlainDriver.GetVariables.datatypes[Z_SQLMONEY]) or
      (ColType = FPlainDriver.GetVariables.datatypes[Z_SQLMONEY4]) or
      (ColType = FPlainDriver.GetVariables.datatypes[Z_SQLMONEYN]);;
    ColumnInfo.Precision := FPlainDriver.dbCollen(FHandle, I);
    ColumnInfo.Scale := 0;
    if ColType = FPlainDriver.GetVariables.datatypes[Z_SQLINT1] then
      ColumnInfo.Signed := False
    else
      ColumnInfo.Signed := True;

    ColumnsInfo.Add(ColumnInfo);

    DBLibColTypeCache[I] := ColType;
  end;
  inherited Open;
end;

{**
  Releases this <code>ResultSet</code> object's database and
  JDBC resources immediately instead of waiting for
  this to happen when it is automatically closed.

  <P><B>Note:</B> A <code>ResultSet</code> object
  is automatically closed by the
  <code>Statement</code> object that generated it when
  that <code>Statement</code> object is closed,
  re-executed, or is used to retrieve the next result from a
  sequence of multiple results. A <code>ResultSet</code> object
  is also automatically closed when it is garbage collected.
}
procedure TZDBLibResultSet.Close;
begin
{ TODO -ofjanos -cGeneral : Maybe it needs a dbcanquery here. }
//  if Assigned(FHandle) then
//    if not FPlainDriver.dbDead(FHandle) then
//      if FPlainDriver.dbCanQuery(FHandle) <> DBSUCCEED then
//        FDBLibConnection.CheckDBLibError(lcDisconnect, 'CLOSE QUERY');
  FHandle := nil;
  SetLength(DBLibColTypeCache, 0);
  inherited Close;
end;

{**
  Checks if the columnindex is in the proper range.
  An exception is generated if somthing is not ok.

  @param columnIndex the first column is 1, the second is 2, ...
}
procedure TZDBLibResultSet.CheckColumnIndex(ColumnIndex: Integer);
begin
  if (ColumnIndex > DBLibColumnCount) or (ColumnIndex < 1) then
  begin
    raise EZSQLException.Create(
      Format(SColumnIsNotAccessable, [ColumnIndex]));
  end;
end;

{**
  Indicates if the value of the designated column in the current row
  of this <code>ResultSet</code> object is Null.

  @param columnIndex the first column is 1, the second is 2, ...
  @return if the value is SQL <code>NULL</code>, the
    value returned is <code>true</code>. <code>false</code> otherwise.
}
function TZDBLibResultSet.IsNull(ColumnIndex: Integer): Boolean;
begin
  CheckClosed;
  CheckColumnIndex(ColumnIndex);
  Result := FPlainDriver.dbData(FHandle, ColumnIndex) = nil;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>TZAnsiRec</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZDBLibResultSet.GetAnsiRec(ColumnIndex: Integer): TZAnsiRec;
begin
  FRawTemp := InternalGetString(ColumnIndex);
  if TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage = zCP_NONE then
    if TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnType in [stString, stUnicodeString, stAsciiStream, stUnicodeStream]  then
      case DetectUTF8Encoding(FRawTemp) of
        etUTF8:
          TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage := zCP_UTF8;
        etAnsi:
          TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage := ConSettings^.ClientCodePage^.CP;
      end;
  Result.P := PAnsiChar(FRawTemp);
  Result.Len := Length(FRawTemp);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>String</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZDBLibResultSet.GetString(ColumnIndex: Integer): String;
var Tmp: RawByteString;
begin
  case TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnType of
    stAsciiStream, stUnicodeStream:
      begin
        Tmp := InternalGetString(ColumnIndex);
        Result := ZConvertRawToString(tmp, ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP);
      end;
    stString, stUnicodeString:
      if TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage = zCP_NONE then
      begin
        Tmp := InternalGetString(ColumnIndex);
        case DetectUTF8Encoding(Tmp) of
          etUTF8:
            begin
              TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage := zCP_UTF8;
              Result := ZConvertRawToString(Tmp, zCP_UTF8, ConSettings^.CTRL_CP);
            end;
          etAnsi:
            begin
              TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage := ConSettings^.ClientCodePage^.CP;
              Result := ZConvertRawToString(tmp, ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP);
            end;
          else
            Result := {$IFDEF UNICODE}PosEmptyASCII7ToString{$ENDIF}(tmp);
        end;
      end
      else
        Result := ZConvertRawToString(InternalGetString(ColumnIndex),
          TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage, ConSettings^.CTRL_CP);
    else
      Result := ZMoveRawToString(InternalGetString(ColumnIndex), ConSettings^.ClientCodePage^.CP,
        ConSettings^.CTRL_CP);
  end;
end;

function TZDBLibResultSet.GetAnsiString(ColumnIndex: Integer): AnsiString;
var Tmp: RawByteString;
begin
  case TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnType of
    stAsciiStream, stUnicodeStream:
      Result := ZMoveRawToAnsi(InternalGetString(ColumnIndex), ConSettings^.ClientCodePage^.CP);
    stString, stUnicodeString:
      if TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage = zCP_NONE then
      begin
        Tmp := InternalGetString(ColumnIndex);
        case DetectUTF8Encoding(Tmp) of
          etUTF8:
            begin
              TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage := zCP_UTF8;
              Result := ZConvertRawToAnsi(Tmp, zCP_UTF8);
            end;
          etAnsi:
            begin
              TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage := ConSettings^.ClientCodePage^.CP;
              Result := ZMoveRawToAnsi(Tmp, ConSettings^.ClientCodePage^.CP);
            end;
          else
            Result := ZMoveRawToAnsi(Tmp, ConSettings^.ClientCodePage^.CP);
        end;
      end
      else
        Result := ZMoveRawToAnsi(InternalGetString(ColumnIndex), ConSettings^.ClientCodePage^.CP)
    else
      Result := ZMoveRawToAnsi(InternalGetString(ColumnIndex), ConSettings^.ClientCodePage^.CP);
  end;
end;

function TZDBLibResultSet.GetUTF8String(ColumnIndex: Integer): UTF8String;
var Tmp: RawByteString;
begin
  case TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnType of
    stAsciiStream, stUnicodeStream:  //DBlib doesn't convert NTEXT so in all cases we've ansi-Encoding
      Result := ZConvertRawToUTF8(InternalGetString(ColumnIndex), ConSettings^.ClientCodePage^.CP);
    stString, stUnicodeString:
      if TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage = zCP_NONE then
      begin
        Tmp := InternalGetString(ColumnIndex);
        case DetectUTF8Encoding(Tmp) of
          etUTF8:
            begin
              TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage := zCP_UTF8;
              Result := ZMoveRawToUTF8(Tmp, zCP_UTF8);
            end;
          etAnsi:
            begin
              TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage := ConSettings^.ClientCodePage^.CP;
              Result := ZConvertRawToUTF8(Tmp, ConSettings^.ClientCodePage^.CP);
            end;
          else
            Result := ZMoveRawToUTF8(Tmp, ConSettings^.ClientCodePage^.CP);
        end;
      end
      else
        if ZCompatibleCodePages(TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage, zCP_UTF8) then
          Result := ZMoveRawToUTF8(InternalGetString(ColumnIndex), zCP_UTF8)
        else
          Result := ZConvertRawToUTF8(InternalGetString(ColumnIndex),
            TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage)
    else
      Result := ZMoveRawToUTF8(InternalGetString(ColumnIndex), zCP_UTF8);
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>WideString/UnicodeString</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZDBLibResultSet.GetUnicodeString(ColumnIndex: Integer): ZWideString;
var Tmp: RawByteString;
begin
  case TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnType of
    stAsciiStream, stUnicodeStream:  //DBlib doesn't convert NTEXT so in all cases we've ansi-Encoding
      Result := ConSettings^.ConvFuncs.ZRawToUnicode(InternalGetString(ColumnIndex), ConSettings^.ClientCodePage^.CP);
    stString, stUnicodeString:
      if TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage = zCP_NONE then
      begin
        Tmp := InternalGetString(ColumnIndex);
        case DetectUTF8Encoding(Tmp) of
          etUTF8:
            begin
              TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage := zCP_UTF8;
              Result := ConSettings^.ConvFuncs.ZRawToUnicode(Tmp, zCP_UTF8);
            end;
          etAnsi:
            begin
              TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage := ConSettings^.ClientCodePage^.CP;
              Result := ConSettings^.ConvFuncs.ZRawToUnicode(tmp, ConSettings^.ClientCodePage^.CP);
            end;
          else
            Result := PosEmptyASCII7ToUnicodeString(tmp);
        end;
      end
      else
        Result := ZRawToUnicode(InternalGetString(ColumnIndex),
          TZColumnInfo(ColumnsInfo[ColumnIndex-1]).ColumnCodePage);
    else
      Result := PosEmptyASCII7ToUnicodeString(InternalGetString(ColumnIndex));
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>String</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZDBLibResultSet.InternalGetString(ColumnIndex: Integer): RawByteString;
var
  DL: Integer;
  Data: Pointer;
  DT: Integer;
begin
  CheckClosed;
  CheckColumnIndex(ColumnIndex);

  DL := FPlainDriver.dbDatLen(FHandle, ColumnIndex);
  Data := FPlainDriver.dbdata(FHandle, ColumnIndex);
  DT := DBLibColTypeCache[ColumnIndex];
  LastWasNull := Data = nil;
  if LastWasNull then
    Result := ''
  else
  begin
    Result := '';
    if Assigned(Data) then
    begin
      if (DT = FPlainDriver.GetVariables.datatypes[Z_SQLCHAR]) or
        (DT = FPlainDriver.GetVariables.datatypes[Z_SQLTEXT]) then
      begin
        while (DL > 0) and (PAnsiChar(NativeUint(Data) + NativeUint(DL - 1))^ = ' ') do
                Dec(DL);
        if DL > 0 then
        begin
          SetLength(Result, DL);
          Move(Data^, PAnsiChar(Result)^, DL);
        end;
      end else
      if (DT = FPlainDriver.GetVariables.datatypes[Z_SQLIMAGE]) then
      begin
        SetLength(Result, DL);
        Move(Data^, PAnsiChar(Result)^, DL);
      end else
      begin
        SetLength(Result, 4001);
        DL := FPlainDriver.dbconvert(FHandle, DT, Data, DL,
          FPlainDriver.GetVariables.datatypes[Z_SQLCHAR], Pointer(PAnsiChar(Result)), Length(Result));
        while (DL > 0) and (Result[DL] = ' ') do
            Dec(DL);
        SetLength(Result, DL);
      end;
    end;
  end;
  FDBLibConnection.CheckDBLibError(lcOther, 'GETSTRING');
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>boolean</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>false</code>
}
function TZDBLibResultSet.GetBoolean(ColumnIndex: Integer): Boolean;
var
  DL: Integer;
  Data: Pointer;
  DT: Integer;
begin
  CheckClosed;
  CheckColumnIndex(ColumnIndex);

  DL := FPlainDriver.dbdatlen(FHandle, ColumnIndex);
  Data := FPlainDriver.dbdata(FHandle, ColumnIndex);
  DT := DBLibColTypeCache[ColumnIndex];
  LastWasNull := Data = nil;

  Result := False;
  if Assigned(Data) then
  begin
    if DT = FPlainDriver.GetVariables.datatypes[Z_SQLBIT] then
      Result := PBoolean(Data)^
    else
    begin
      FPlainDriver.dbconvert(FHandle, DT, Data, DL, FPlainDriver.GetVariables.datatypes[Z_SQLBIT],
        @Result, SizeOf(Result));
    end;
  end;
  FDBLibConnection.CheckDBLibError(lcOther, 'GETBOOLEAN');
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>byte</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZDBLibResultSet.GetByte(ColumnIndex: Integer): Byte;
var
  DL: Integer;
  Data: Pointer;
  DT: Integer;
begin
  CheckClosed;
  CheckColumnIndex(ColumnIndex);

  DL := FPlainDriver.dbdatlen(FHandle, ColumnIndex);
  Data := FPlainDriver.dbdata(FHandle, ColumnIndex);
  DT := DBLibColTypeCache[ColumnIndex];
  LastWasNull := Data = nil;

  Result := 0;
  if Assigned(Data) then
  begin
    if DT = FPlainDriver.GetVariables.datatypes[Z_SQLINT1] then
      Result := PByte(Data)^
    else
    begin
      FPlainDriver.dbconvert(FHandle, DT, Data, DL, FPlainDriver.GetVariables.datatypes[Z_SQLINT1],
        @Result, SizeOf(Result));
    end;
  end;
  FDBLibConnection.CheckDBLibError(lcOther, 'GETBYTE');
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>short</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZDBLibResultSet.GetSmall(ColumnIndex: Integer): SmallInt;
var
  DL: Integer;
  Data: Pointer;
  DT: Integer;
begin
  CheckClosed;
  CheckColumnIndex(ColumnIndex);

  DL := FPlainDriver.dbdatlen(FHandle, ColumnIndex);
  Data := FPlainDriver.dbdata(FHandle, ColumnIndex);
  DT := DBLibColTypeCache[ColumnIndex];
  LastWasNull := Data = nil;

  Result := 0;
  if Assigned(Data) then
  begin
    if DT = FPlainDriver.GetVariables.datatypes[Z_SQLINT2] then
      Result := PSmallInt(Data)^
    else
    begin
      FPlainDriver.dbconvert(FHandle, DT, Data, DL, FPlainDriver.GetVariables.datatypes[Z_SQLINT2],
        @Result, SizeOf(Result));
    end;
  end;
  FDBLibConnection.CheckDBLibError(lcOther, 'GetSmall');
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  an <code>int</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZDBLibResultSet.GetInt(ColumnIndex: Integer): Integer;
var
  DL: Integer;
  Data: Pointer;
  DT: Integer;
begin
  CheckClosed;
  CheckColumnIndex(ColumnIndex);

  DL := FPlainDriver.dbdatlen(FHandle, ColumnIndex);
  Data := FPlainDriver.dbdata(FHandle, ColumnIndex);
  DT := DBLibColTypeCache[ColumnIndex];
  LastWasNull := Data = nil;

  Result := 0;
  if Assigned(Data) then
  begin
    if DT = FPlainDriver.GetVariables.datatypes[Z_SQLINT4] then
      Result := PLongint(Data)^
    else
    begin
      FPlainDriver.dbconvert(FHandle, DT, Data, DL, FPlainDriver.GetVariables.datatypes[Z_SQLINT4],
        @Result, SizeOf(Result));
    end;
  end;
  FDBLibConnection.CheckDBLibError(lcOther, 'GETINT');
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>long</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZDBLibResultSet.GetLong(ColumnIndex: Integer): Int64;
begin
  Result := GetInt(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>float</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZDBLibResultSet.GetFloat(ColumnIndex: Integer): Single;
var
  DL: Integer;
  Data: Pointer;
  DT: Integer;
begin
  CheckClosed;
  CheckColumnIndex(ColumnIndex);

  DL := FPlainDriver.dbdatlen(FHandle, ColumnIndex);
  Data := FPlainDriver.dbdata(FHandle, ColumnIndex);
  DT := DBLibColTypeCache[ColumnIndex];
  LastWasNull := Data = nil;

  Result := 0;
  if Assigned(Data) then
  begin
    if DT = FPlainDriver.GetVariables.datatypes[Z_SQLFLT4] then
      Result := PSingle(Data)^
    else
    begin
      FPlainDriver.dbconvert(FHandle, DT, Data, DL, FPlainDriver.GetVariables.datatypes[Z_SQLFLT4],
        @Result, SizeOf(Result));
    end;
  end;
  FDBLibConnection.CheckDBLibError(lcOther, 'GETFLOAT');
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>double</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZDBLibResultSet.GetDouble(ColumnIndex: Integer): Double;
var
  DL: Integer;
  Data: Pointer;
  DT: Integer;
begin
  CheckClosed;
  CheckColumnIndex(ColumnIndex);

  DL := FPlainDriver.dbdatlen(FHandle, ColumnIndex);
  Data := FPlainDriver.dbdata(FHandle, ColumnIndex);
  DT := DBLibColTypeCache[ColumnIndex];
  LastWasNull := Data = nil;

  Result := 0;
  if Assigned(Data) then
  begin
    if DT = FPlainDriver.GetVariables.datatypes[Z_SQLFLT8] then
      Result := PDouble(Data)^
    else
    begin
      FPlainDriver.dbconvert(FHandle, DT, Data, DL, FPlainDriver.GetVariables.datatypes[Z_SQLFLT8],
        @Result, SizeOf(Result));
    end;
  end;
  FDBLibConnection.CheckDBLibError(lcOther, 'GETDOUBLE');
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.BigDecimal</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param scale the number of digits to the right of the decimal point
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZDBLibResultSet.GetBigDecimal(ColumnIndex: Integer): Extended;
begin
  Result := GetDouble(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>byte</code> array in the Java programming language.
  The bytes represent the raw values returned by the driver.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZDBLibResultSet.GetBytes(ColumnIndex: Integer): TBytes;
var
  DL: Integer;
  Data: Pointer;
begin
  CheckClosed;
  CheckColumnIndex(ColumnIndex);

  DL := FPlainDriver.dbdatlen(FHandle, ColumnIndex);
  Data := FPlainDriver.dbdata(FHandle, ColumnIndex);
  FDBLibConnection.CheckDBLibError(lcOther, 'GETBYTES');
  LastWasNull := Data = nil;

  SetLength(Result, DL);
  if Assigned(Data) then
      Move(PAnsiChar(Data)^, Result[0], DL);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Date</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZDBLibResultSet.GetDate(ColumnIndex: Integer): TDateTime;
begin
  Result := System.Int(GetTimestamp(ColumnIndex));
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Time</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZDBLibResultSet.GetTime(ColumnIndex: Integer): TDateTime;
begin
  Result := Frac(GetTimestamp(ColumnIndex));
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Timestamp</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
  value returned is <code>null</code>
  @exception SQLException if a database access error occurs
}
function TZDBLibResultSet.GetTimestamp(ColumnIndex: Integer): TDateTime;
var
  DL: Integer;
  Data: Pointer;
  DT: Integer;
  TempDate: DBDATETIME;
begin
  CheckClosed;
  CheckColumnIndex(ColumnIndex);

  DL := FPlainDriver.dbdatlen(FHandle, ColumnIndex);
  Data := FPlainDriver.dbdata(FHandle, ColumnIndex);
  DT := DBLibColTypeCache[ColumnIndex];
  LastWasNull := Data = nil;

  Result := 0;
  if Assigned(Data) then
  begin
    if DT = FPlainDriver.GetVariables.datatypes[Z_SQLDATETIME] then
      Move(Data^, TempDate, SizeOf(TempDate))
    else
    begin
      FPlainDriver.dbconvert(FHandle, DT, Data, DL, FPlainDriver.GetVariables.datatypes[Z_SQLDATETIME],
        @TempDate, SizeOf(TempDate));
    end;
    Result := TempDate.dtdays + 2 + (TempDate.dttime / 25920000);
    //Perfect conversion no need to crack and reencode the date.
  end;
  FDBLibConnection.CheckDBLibError(lcOther, 'GETTIMESTAMP');
end;

{**
  Returns the value of the designated column in the current row
  of this <code>ResultSet</code> object as a <code>Blob</code> object
  in the Java programming language.

  @param ColumnIndex the first column is 1, the second is 2, ...
  @return a <code>Blob</code> object representing the SQL <code>BLOB</code> value in
    the specified column
}
function TZDBLibResultSet.GetBlob(ColumnIndex: Integer): IZBlob;
var
  DL: Integer;
  Data: Pointer;
  TempAnsi: RawByteString;
  US: ZWideString;
begin
  CheckClosed;
  CheckColumnIndex(ColumnIndex);
  CheckBlobColumn(ColumnIndex);

  DL := FPlainDriver.dbdatlen(FHandle, ColumnIndex);
  Data := FPlainDriver.dbdata(FHandle, ColumnIndex);
  LastWasNull := Data = nil;

  Result := nil;
  if not LastWasNull then
    case GetMetaData.GetColumnType(ColumnIndex) of
      stBytes, stBinaryStream:
        Result := TZAbstractBlob.CreateWithData(Data, DL);
      stAsciiStream, stUnicodeStream:
        begin
          if (DL = 1) and (PAnsiChar(Data)^ = ' ') then DL := 0; //improve empty lobs, where len = 1 but string should be ''
          Result := TZAbstractClob.CreateWithData(Data, DL,
            ConSettings^.ClientCodePage^.CP, ConSettings);
        end;
      stString, stUnicodeString:
        begin
          US := GetUnicodeString(ColumnIndex);
          Result := TZAbstractClob.CreateWithData(PWideChar(US), Length(US),
            ConSettings);
        end
      else
      begin
        TempAnsi := InternalGetString(ColumnIndex);
        Result := TZAbstractClob.CreateWithData(PAnsiChar(TempAnsi),
          Length(TempAnsi), ConSettings^.ClientCodePage^.CP, ConSettings);
      end;
    end;
end;

{**
  Moves the cursor down one row from its current position.
  A <code>ResultSet</code> cursor is initially positioned
  before the first row; the first call to the method
  <code>next</code> makes the first row the current row; the
  second call makes the second row the current row, and so on.

  <P>If an input stream is open for the current row, a call
  to the method <code>next</code> will
  implicitly close it. A <code>ResultSet</code> object's
  warning chain is cleared when a new row is read.

  @return <code>true</code> if the new current row is valid;
    <code>false</code> if there are no more rows
}
function TZDBLibResultSet.Next: Boolean;
begin
  Result := False;
  if FPlainDriver.GetProtocol = 'mssql' then
    if FPlainDriver.dbDead(FHandle) then
      Exit;
//!!! maybe an error message other than dbconnection is dead should be raised
  case FPlainDriver.dbnextrow(FHandle) of
    REG_ROW: Result := True;
    NO_MORE_ROWS: ;
    DBFAIL: FDBLibConnection.CheckDBLibError(lcOther, 'NEXT');
    BUF_FULL: ;//should not happen because we are not using dblibc buffering.
  else
   // If a compute row is read, the computeid of the row is returned
    Result := False;
  end;
end;


{ TZDBLibCachedResolver }

{**
  Creates a DBLib specific cached resolver object.
  @param PlainDriver a native DBLib plain driver.
  @param Handle a DBLib specific query handle.
  @param Statement a related SQL statement object.
  @param Metadata a resultset metadata reference.
}
constructor TZDBLibCachedResolver.Create(Statement: IZStatement;
  Metadata: IZResultSetMetadata);
begin
  inherited Create(Statement, Metadata);

  { Defines an index of autoincrement field. }
  FAutoColumnIndex := -1;
end;

{**
  Posts updates to database.
  @param Sender a cached result set object.
  @param UpdateType a type of updates.
  @param OldRowAccessor an accessor object to old column values.
  @param NewRowAccessor an accessor object to new column values.
}
procedure TZDBLibCachedResolver.PostUpdates(Sender: IZCachedResultSet;
  UpdateType: TZRowUpdateType; OldRowAccessor, NewRowAccessor: TZRowAccessor);
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
  I: Integer;
begin
  inherited PostUpdates(Sender, UpdateType, OldRowAccessor, NewRowAccessor);

  { Defines an index of autoincrement field. }
  if FAutoColumnIndex = -1 then
  begin
    FAutoColumnIndex := 0;
    for I := 1 to Metadata.GetColumnCount do
    begin
      if Metadata.IsAutoIncrement(I) then
      begin
        FAutoColumnIndex := I;
        Break;
      end;
    end;
  end;

  if (UpdateType = utInserted) and (FAutoColumnIndex > 0)
    and OldRowAccessor.IsNull(FAutoColumnIndex) then
  begin
    Statement := Connection.CreateStatement;
    ResultSet := Statement.ExecuteQuery('SELECT @@IDENTITY');
    try
      if ResultSet.Next then
        NewRowAccessor.SetLong(FAutoColumnIndex, ResultSet.GetLong(1));
    finally
      ResultSet.Close;
      Statement.Close;
    end;
  end;
end;

end.

