{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{           SQLite Database Connectivity Classes          }
{                                                         }
{        Originally written by Sergey Seroukhov           }
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

unit ZDbcSqLiteResultSet;

interface

{$I ZDbc.inc}

uses
  {$IFDEF WITH_TOBJECTLIST_INLINE}System.Types, System.Contnrs{$ELSE}Contnrs{$ENDIF},
  Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils,
  ZSysUtils, ZDbcIntfs, ZDbcResultSet, ZDbcResultSetMetadata, ZPlainSqLiteDriver,
  ZCompatibility, ZDbcCache, ZDbcCachedResultSet, ZDbcGenericResolver;

type
  {** Implements SQLite ResultSet Metadata. }
  TZSQLiteResultSetMetadata = class(TZAbstractResultSetMetadata)
  public
//    function IsAutoIncrement(Column: Integer): Boolean; override;
    function IsNullable(Column: Integer): TZColumnNullableType; override;
  end;

  {** Implements SQLite ResultSet. }
  TZSQLiteResultSet = class(TZAbstractResultSet)
  private
    FErrorCode: Integer;
    FHandle: Psqlite;
    FStmtHandle: Psqlite_vm;
    FColumnCount: Integer;
    FPlainDriver: IZSQLitePlainDriver;
    FFirstRow: Boolean;
    FUndefinedVarcharAsStringLength: Integer;
  protected
    procedure Open; override;
    function InternalGetString(ColumnIndex: Integer): RawByteString; override;
  public
    constructor Create(PlainDriver: IZSQLitePlainDriver; Statement: IZStatement;
      SQL: string; const Handle: Psqlite; const StmtHandle: Psqlite_vm;
      const UndefinedVarcharAsStringLength: Integer);

    procedure ResetCursor; override;

    function IsNull(ColumnIndex: Integer): Boolean; override;
    function GetPAnsiChar(ColumnIndex: Integer; out Len: NativeUInt): PAnsiChar; override;
    function GetPAnsiChar(ColumnIndex: Integer): PAnsiChar; override;
    function GetUTF8String(ColumnIndex: Integer): UTF8String; override;
    function GetBoolean(ColumnIndex: Integer): Boolean; override;
    function GetInt(ColumnIndex: Integer): Integer; override;
    function GetLong(ColumnIndex: Integer): Int64; override;
    function GetULong(ColumnIndex: Integer): UInt64; override;
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

  {** Implements a cached resolver with SQLite specific functionality. }
  TZSQLiteCachedResolver = class (TZGenericCachedResolver, IZCachedResolver)
  private
    FHandle: Psqlite;
    FPlainDriver: IZSQLitePlainDriver;
    FAutoColumnIndex: Integer;
  public
    constructor Create(PlainDriver: IZSQLitePlainDriver; Handle: Psqlite;
      Statement: IZStatement; Metadata: IZResultSetMetadata);

    procedure PostUpdates(Sender: IZCachedResultSet; UpdateType: TZRowUpdateType;
      OldRowAccessor, NewRowAccessor: TZRowAccessor); override;

    function FormCalculateStatement(Columns: TObjectList): string; override;

    procedure UpdateAutoIncrementFields(Sender: IZCachedResultSet; UpdateType: TZRowUpdateType;
      OldRowAccessor, NewRowAccessor: TZRowAccessor; Resolver: IZCachedResolver); override;
  end;

implementation

uses
  ZMessages, ZDbcSqLite, ZDbcSQLiteUtils, ZEncoding, ZDbcLogging, ZFastCode,
  ZVariant, ZDbcSqLiteStatement
  {$IFDEF WITH_UNITANSISTRINGS}, AnsiStrings{$ENDIF};

{**
  Indicates the nullability of values in the designated column.
  @param column the first column is 1, the second is 2, ...
  @return the nullability status of the given column; one of <code>columnNoNulls</code>,
    <code>columnNullable</code> or <code>columnNullableUnknown</code>
}
function TZSQLiteResultSetMetadata.IsNullable(Column: Integer):
  TZColumnNullableType;
begin
  if IsAutoIncrement(Column) then
    Result := ntNullable
  else
    Result := inherited IsNullable(Column);
end;

{ TZSQLiteResultSet }

{**
  Constructs this object, assignes main properties and
  opens the record set.
  @param PlainDriver a native SQLite plain driver.
  @param Statement a related SQL statement object.
  @param Handle a SQLite specific query handle.
  @param UseResult <code>True</code> to use results,
    <code>False</code> to store result.
}
constructor TZSQLiteResultSet.Create(PlainDriver: IZSQLitePlainDriver;
  Statement: IZStatement; SQL: string; const Handle: Psqlite;
  const StmtHandle: Psqlite_vm; const UndefinedVarcharAsStringLength: Integer);
begin
  inherited Create(Statement, SQL, TZSQLiteResultSetMetadata.Create(
    Statement.GetConnection.GetMetadata, SQL, Self),
    Statement.GetConnection.GetConSettings);

  FHandle := Handle;
  FStmtHandle := StmtHandle;
  FPlainDriver := PlainDriver;
  ResultSetConcurrency := rcReadOnly;
  FUndefinedVarcharAsStringLength := UndefinedVarcharAsStringLength;
  FFirstRow := True;

  Open;
end;

{**
  Opens this recordset.
}
procedure TZSQLiteResultSet.Open;
var
  I: Integer;
  ColumnInfo: TZColumnInfo;
  FieldPrecision: Integer;
  FieldDecimals: Integer;
  TypeName: PAnsiChar;
begin
  if ResultSetConcurrency = rcUpdatable then
    raise EZSQLException.Create(SLiveResultSetsAreNotSupported);

  FColumnCount := FPlainDriver.column_count(FStmtHandle);

  LastRowNo := 0;
  //MaxRows := FPlainDriver.data_count(FStmtHandle) +1; {first ResultSetRow = 1}

  { Fills the column info. }
  ColumnsInfo.Clear;
  for I := 0 to FColumnCount-1 do
  begin
    ColumnInfo := TZColumnInfo.Create;
    with ColumnInfo do
    begin
      ColumnName := ConSettings^.ConvFuncs.ZRawToString(FPlainDriver.column_origin_name(FStmtHandle, i),
        ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP);
      ColumnLabel := ConSettings^.ConvFuncs.ZRawToString(FPlainDriver.column_name(FStmtHandle, i),
        ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP);
      TableName := ConSettings^.ConvFuncs.ZRawToString(FPlainDriver.column_table_name(FStmtHandle, i),
        ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP);
      SchemaName := ConSettings^.ConvFuncs.ZRawToString(FPlainDriver.column_database_name(FStmtHandle, i),
        ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP);
      ReadOnly := False;
      TypeName := FPlainDriver.column_decltype(FStmtHandle, i);
      if TypeName = nil then
        ColumnType := ConvertSQLiteTypeToSQLType(FPlainDriver.column_type_AsString(FStmtHandle, i),
          FUndefinedVarcharAsStringLength, FieldPrecision{%H-}, FieldDecimals{%H-},
          ConSettings.CPType)
      else
        ColumnType := ConvertSQLiteTypeToSQLType(TypeName,
          FUndefinedVarcharAsStringLength, FieldPrecision, FieldDecimals,
          ConSettings.CPType);

      if ColumnType in [stString, stUnicodeString, stAsciiStream, stUnicodeStream] then
      begin
        ColumnCodePage := zCP_UTF8;
        if ColumnType = stString then
          if ZDefaultSystemCodePage = zCP_UTF8 then
            ColumnDisplaySize := FieldPrecision shr 2 //shr 2 = div 4 but faster
          else
            ColumnDisplaySize := FieldPrecision shr 1; //shr 1 = div 2 but faster

        if ColumnType = stUnicodeString then
          ColumnDisplaySize := FieldPrecision shr 1; //shr 1 = div 2 but faster
      end
      else
        ColumnCodePage := zCP_NONE;

      AutoIncrement := False;
      Precision := FieldPrecision;
      Scale := FieldDecimals;
      Signed := True;
      Nullable := ntNullable;
    end;

    ColumnsInfo.Add(ColumnInfo);
  end;

  inherited Open;

end;

{**
  Resets cursor position of this recordset and
  reset the prepared handles.
}
procedure TZSQLiteResultSet.ResetCursor;
begin
  FFirstRow := True;
  if Assigned(FStmtHandle) then
  begin
    CheckSQLiteError(FPlainDriver, FHandle, FPlainDriver.reset(FStmtHandle),
      nil, lcOther, 'Reset Prepared Stmt', ConSettings);
    FStmtHandle := nil;
  end;
  inherited ResetCursor;
end;

{**
  Indicates if the value of the designated column in the current row
  of this <code>ResultSet</code> object is Null.

  @param columnIndex the first column is 1, the second is 2, ...
  @return if the value is SQL <code>NULL</code>, the
    value returned is <code>true</code>. <code>false</code> otherwise.
}
function TZSQLiteResultSet.IsNull(ColumnIndex: Integer): Boolean;
begin
  Result := FPlainDriver.column_type(FStmtHandle, ColumnIndex{$IFNDEF GENERIC_INDEX} -1{$ENDIF}) = SQLITE_NULL;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>PAnsiChar</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param Len the Length of the String in bytes
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZSQLiteResultSet.GetPAnsiChar(ColumnIndex: Integer; out Len: NativeUInt): PAnsiChar;
var ColType: Integer;
begin
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}
  ColType := FPlainDriver.column_type(FStmtHandle, ColumnIndex);
  LastWasNull := ColType = SQLITE_NULL;
  if LastWasNull then
  begin
    Result := nil;
    Len := 0;
  end
  else
    if ColType <> SQLITE_BLOB then
    begin
      Result := FPlainDriver.column_text(FStmtHandle, ColumnIndex);
      Len := ZFastCode.StrLen(Result);
    end
    else
    begin
      Result := FPlainDriver.column_blob(FStmtHandle, ColumnIndex);
      Len := FPlainDriver.column_bytes(FStmtHandle, ColumnIndex);
    end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>PAnsiChar</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZSQLiteResultSet.GetPAnsiChar(ColumnIndex: Integer): PAnsiChar;
begin
  Result := FPlainDriver.column_text(FStmtHandle, ColumnIndex{$IFNDEF GENERIC_INDEX} -1{$ENDIF});
  LastWasNull := Result = nil;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>UTF8String</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZSQLiteResultSet.GetUTF8String(ColumnIndex: Integer): UTF8String;
var P: PAnsiChar;
  Len: NativeUint;
begin //rewritten because of performance reasons to avoid localized the RBS before
  LastWasNull := FPlainDriver.column_type(FStmtHandle, ColumnIndex{$IFNDEF GENERIC_INDEX} -1{$ENDIF}) = SQLITE_NULL;
  if LastWasNull then
    Result := ''
  else
  begin
    P := GetPAnsiChar(ColumnIndex, Len);
    {$IFDEF MISS_RBS_SETSTRING_OVERLOAD}
    ZSetString(P, Len, result);
    {$ELSE}
    System.SetString(Result, P, Len);
    {$ENDIF}
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
function TZSQLiteResultSet.InternalGetString(ColumnIndex: Integer): RawByteString;
var
  Buffer: PAnsiChar;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stString);
{$ENDIF}
  Buffer := FPlainDriver.column_text(FStmtHandle, ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF});
  LastWasNull := Buffer = nil;
  if LastWasNull then
    Result := ''
  else
    Result := Buffer;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>boolean</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>false</code>
}
function TZSQLiteResultSet.GetBoolean(ColumnIndex: Integer): Boolean;
var
  ColType: Integer;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBoolean);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}
  ColType := FPlainDriver.column_type(FStmtHandle, ColumnIndex);

  LastWasNull := ColType = SQLITE_NULL;
  if LastWasNull then
    Result := False
  else
    case ColType of
      SQLITE_INTEGER:
        Result := FPlainDriver.column_int(FStmtHandle, ColumnIndex) <> 0;
      SQLITE_FLOAT:
        Result := FPlainDriver.column_double(FStmtHandle, ColumnIndex) <> 0;
      SQLITE3_TEXT:
        Result := StrToBoolEx(FPlainDriver.column_text(FStmtHandle, ColumnIndex), True, False);
      else
        Result := False; {SQLITE_BLOB}
    end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  an <code>int</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZSQLiteResultSet.GetInt(ColumnIndex: Integer): Integer;
var
  ColType: Integer;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stInteger);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}
  ColType := FPlainDriver.column_type(FStmtHandle, ColumnIndex);
  LastWasNull := ColType = SQLITE_NULL;
  if LastWasNull then
    Result := 0
  else
    case ColType of
      SQLITE_INTEGER:
        Result := FPlainDriver.column_int(FStmtHandle, ColumnIndex);
      SQLITE_FLOAT:
        Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(FPlainDriver.column_double(FStmtHandle, ColumnIndex));
      SQLITE3_TEXT:
        Result := RawToIntDef(FPlainDriver.column_text(FStmtHandle, ColumnIndex), 0);
      else
        Result := 0; {SQLITE_BLOB}
    end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>long</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZSQLiteResultSet.GetLong(ColumnIndex: Integer): Int64;
var
  ColType: Integer;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stLong);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}
  ColType := FPlainDriver.column_type(FStmtHandle, ColumnIndex);
  LastWasNull := ColType = SQLITE_NULL;
  if LastWasNull then
    Result := 0
  else
    case ColType of
      SQLITE_INTEGER:
        Result := FPlainDriver.column_int64(FStmtHandle, ColumnIndex);
      SQLITE_FLOAT:
        Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(FPlainDriver.column_double(FStmtHandle, ColumnIndex));
      SQLITE3_TEXT:
        Result := RawToInt64Def(FPlainDriver.column_text(FStmtHandle, ColumnIndex), 0);
      else
        Result := 0; {SQLITE_BLOB}
    end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>UInt64</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZSQLiteResultSet.GetULong(ColumnIndex: Integer): UInt64;
var
  ColType: Integer;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stLong);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}
  ColType := FPlainDriver.column_type(FStmtHandle, ColumnIndex);
  LastWasNull := ColType = SQLITE_NULL;
  if LastWasNull then
    Result := 0
  else
    case ColType of
      SQLITE_INTEGER:
        Result := FPlainDriver.column_int64(FStmtHandle, ColumnIndex);
      SQLITE_FLOAT:
        Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(FPlainDriver.column_double(FStmtHandle, ColumnIndex));
      SQLITE3_TEXT:
        Result := RawToUInt64Def(FPlainDriver.column_text(FStmtHandle, ColumnIndex), 0);
      else
        Result := 0;
    end;
end;
{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>float</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZSQLiteResultSet.GetFloat(ColumnIndex: Integer): Single;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stFloat);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}
  LastWasNull := FPlainDriver.column_type(FStmtHandle, ColumnIndex) = SQLITE_NULL;
  if LastWasNull then
    Result := 0
  else
    { sqlite does the conversion if required
      http://www.sqlite.org/c3ref/column_blob.html }
     Result := FPlainDriver.column_double(FStmtHandle, ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>double</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZSQLiteResultSet.GetDouble(ColumnIndex: Integer): Double;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stDouble);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}

  LastWasNull := FPlainDriver.column_type(FStmtHandle, ColumnIndex) = SQLITE_NULL;
  if LastWasNull then
    Result := 0
  else
    { sqlite does the conversion if required
      http://www.sqlite.org/c3ref/column_blob.html }
     Result := FPlainDriver.column_double(FStmtHandle, ColumnIndex);
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
function TZSQLiteResultSet.GetBigDecimal(ColumnIndex: Integer): Extended;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBigDecimal);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}

  LastWasNull := FPlainDriver.column_type(FStmtHandle, ColumnIndex) = SQLITE_NULL;
  if LastWasNull then
    Result := 0
  else
    { sqlite does the conversion if required
      http://www.sqlite.org/c3ref/column_blob.html }
     Result := FPlainDriver.column_double(FStmtHandle, ColumnIndex);
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
function TZSQLiteResultSet.GetBytes(ColumnIndex: Integer): TBytes;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBytes);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}

  LastWasNull := FPlainDriver.column_type(FStmtHandle, ColumnIndex) = SQLITE_NULL;
  if LastWasNull then
    Result := nil
  else
    Result := FPlainDriver.column_blob_AsBytes(FStmtHandle, ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Date</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZSQLiteResultSet.GetDate(ColumnIndex: Integer): TDateTime;
var
  ColType: Integer;
  Buffer: PAnsiChar;
  Len: Cardinal;
  Failed: Boolean;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stDate);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}
  ColType := FPlainDriver.column_type(FStmtHandle, ColumnIndex);

  LastWasNull := ColType = SQLITE_NULL;
  if LastWasNull then
    Result := 0
  else
    case ColType of
      SQLITE_INTEGER, SQLITE_FLOAT:
        Result := FPlainDriver.column_double(FStmtHandle, ColumnIndex)+JulianEpoch;
      else
      begin
        Buffer := FPlainDriver.column_text(FStmtHandle, ColumnIndex);
        Len := ZFastCode.StrLen(Buffer);

        if (Len = ConSettings^.ReadFormatSettings.DateFormatLen) then
          Result := RawSQLDateToDateTime(Buffer,  Len, ConSettings^.ReadFormatSettings, Failed{%H-})
        else
          Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(
            RawSQLTimeStampToDateTime(Buffer,  Len, ConSettings^.ReadFormatSettings, Failed));
      end;
      LastWasNull := Result = 0;
    end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Time</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZSQLiteResultSet.GetTime(ColumnIndex: Integer): TDateTime;
var
  ColType: Integer;
  Buffer: PAnsiChar;
  Len: Cardinal;
  Failed: Boolean;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stTime);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}
  ColType := FPlainDriver.column_type(FStmtHandle, ColumnIndex);

  LastWasNull := ColType = SQLITE_NULL;
  if LastWasNull then
    Result := 0
  else
    case ColType of
      SQLITE_INTEGER, SQLITE_FLOAT:
        Result := FPlainDriver.column_double(FStmtHandle, ColumnIndex)+JulianEpoch;
      else
      begin
        Buffer := FPlainDriver.column_text(FStmtHandle, ColumnIndex);
        Len := ZFastCode.StrLen(Buffer);

        if ((Buffer)+2)^ = ':' then //possible date if Len = 10 then
          Result := RawSQLTimeToDateTime(Buffer, Len, ConSettings^.ReadFormatSettings, Failed{%H-})
        else
          Result := Frac(RawSQLTimeStampToDateTime(Buffer, Len,
            ConSettings^.ReadFormatSettings, Failed));
      end;
      LastWasNull := Result = 0;
    end;
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
function TZSQLiteResultSet.GetTimestamp(ColumnIndex: Integer): TDateTime;
var
  ColType: Integer;
  Buffer: PAnsiChar;
  Failed: Boolean;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stTime);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}
  ColType := FPlainDriver.column_type(FStmtHandle, ColumnIndex);

  LastWasNull := ColType = SQLITE_NULL;
  if LastWasNull then
    Result := 0
  else
    case ColType of
      SQLITE_INTEGER,
      SQLITE_FLOAT:
        Result := FPlainDriver.column_double(FStmtHandle, ColumnIndex)+JulianEpoch;
      else
      begin
        Buffer := FPlainDriver.column_text(FStmtHandle, ColumnIndex);
        Result := RawSQLTimeStampToDateTime(Buffer, ZFastCode.StrLen(Buffer), ConSettings^.ReadFormatSettings, Failed{%H-});
      end;
      LastWasNull := Result = 0;
    end;
end;

{**
  Returns the value of the designated column in the current row
  of this <code>ResultSet</code> object as a <code>Blob</code> object
  in the Java programming language.

  @param ColumnIndex the first column is 1, the second is 2, ...
  @return a <code>Blob</code> object representing the SQL <code>BLOB</code> value in
    the specified column
}
function TZSQLiteResultSet.GetBlob(ColumnIndex: Integer): IZBlob;
var
  ColType: Integer;
  Buffer: PAnsiChar;
begin
  Result := nil;
{$IFNDEF DISABLE_CHECKING}
  CheckBlobColumn(ColumnIndex);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex -1;
  {$ENDIF}
  ColType := FPlainDriver.column_type(FStmtHandle, ColumnIndex);

  LastWasNull := ColType = SQLITE_NULL;
  if LastWasNull then
    Exit
  else
    case GetMetadata.GetColumnType(ColumnIndex{$IFNDEF GENERIC_INDEX}+1{$ENDIF}) of
      stAsciiStream, stUnicodeStream:
        begin
          Buffer := FPlainDriver.column_text(FStmtHandle, ColumnIndex);
          Result := TZAbstractClob.CreateWithData( Buffer,
            ZFastCode.StrLen(Buffer), zCP_UTF8, ConSettings);
        end;
      stBinaryStream:
         Result := TZAbstractBlob.CreateWithData(FPlainDriver.column_blob(FStmtHandle,ColumnIndex), FPlainDriver.column_bytes(FStmtHandle, ColumnIndex));
      else
        Result := TZAbstractBlob.CreateWithStream(nil);
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
function TZSQLiteResultSet.Next: Boolean;
label ResetHndl;
begin
  { Checks for maximum row. }
  Result := False;
  if Closed then exit;
  if FFirstRow then
    FErrorCode := (Statement as IZSQLitePreparedStatement).GetLastErrorCodeAndHandle(FStmtHandle);
  if ((MaxRows > 0) and (RowNo >= MaxRows)) or (FErrorCode = SQLITE_DONE) then //previously set by stmt or Next
  begin
    { Free handle when EOF. }
ResetHndl:
    CheckSQLiteError(FPlainDriver, FHandle, FPlainDriver.reset(FStmtHandle),
      nil, lcOther, 'sqlite3_reset', ConSettings);
    FErrorCode := SQLITE_DONE;
    Exit;
  end;

  if (FStmtHandle <> nil ) and not FFirstRow then
  begin
    FErrorCode := FPlainDriver.Step(FStmtHandle);
    CheckSQLiteError(FPlainDriver, FHandle, FErrorCode, nil, lcOther, 'FETCH', ConSettings);
  end;

  if FFirstRow then //avoid incrementing issue on fetching since the first row is allready fetched by stmt
  begin
    FFirstRow := False;
    Result := (FErrorCode = SQLITE_ROW);
    RowNo := 1;
  end
  else
    if (FErrorCode = SQLITE_ROW) then
    begin
      RowNo := RowNo + 1;
      if LastRowNo < RowNo then
        LastRowNo := RowNo;
      Result := True;
    end
    else
    begin
      if RowNo <= LastRowNo then
        RowNo := LastRowNo + 1;
      Result := False;
    end;

  { Free handle when EOF. }
  if not Result then
    goto ResetHndl;
end;

{ TZSQLiteCachedResolver }

{**
  Creates a SQLite specific cached resolver object.
  @param PlainDriver a native SQLite plain driver.
  @param Handle a SQLite specific query handle.
  @param Statement a related SQL statement object.
  @param Metadata a resultset metadata reference.
}
constructor TZSQLiteCachedResolver.Create(PlainDriver: IZSQLitePlainDriver;
  Handle: Psqlite; Statement: IZStatement; Metadata: IZResultSetMetadata);
var
  I: Integer;
begin
  inherited Create(Statement, Metadata);
  FPlainDriver := PlainDriver;
  FHandle := Handle;

  { Defines an index of autoincrement field. }
  FAutoColumnIndex := 0;
  for I := FirstDbcIndex to Metadata.GetColumnCount{$IFDEF GENERIC_INDEX} - 1{$ENDIF} do
  begin
    if Metadata.IsAutoIncrement(I) and
      (Metadata.GetColumnType(I) in [stByte, stShort, stSmall, stLongWord,
        stInteger, stUlong, stLong]) then
    begin
      FAutoColumnIndex := I;
      Break;
    end;
  end;
end;

{**
  Posts updates to database.
  @param Sender a cached result set object.
  @param UpdateType a type of updates.
  @param OldRowAccessor an accessor object to old column values.
  @param NewRowAccessor an accessor object to new column values.
}
procedure TZSQLiteCachedResolver.PostUpdates(Sender: IZCachedResultSet;
  UpdateType: TZRowUpdateType; OldRowAccessor, NewRowAccessor: TZRowAccessor);
begin
  inherited PostUpdates(Sender, UpdateType, OldRowAccessor, NewRowAccessor);

  if (UpdateType = utInserted) then
    UpdateAutoIncrementFields(Sender, UpdateType, OldRowAccessor, NewRowAccessor, Self);
end;

{**
 Do Tasks after Post updates to database.
  @param Sender a cached result set object.
  @param UpdateType a type of updates.
  @param OldRowAccessor an accessor object to old column values.
  @param NewRowAccessor an accessor object to new column values.
}
procedure TZSQLiteCachedResolver.UpdateAutoIncrementFields(
  Sender: IZCachedResultSet; UpdateType: TZRowUpdateType; OldRowAccessor,
  NewRowAccessor: TZRowAccessor; Resolver: IZCachedResolver);
var
  PlainDriver: IZSQLitePlainDriver;
begin
  inherited;

  if (FAutoColumnIndex {$IFDEF GENERIC_INDEX}>={$ELSE}>{$ENDIF} 0) and
     (OldRowAccessor.IsNull(FAutoColumnIndex) or (OldRowAccessor.GetValue(FAutoColumnIndex).VInteger = 0)) then
  begin
    PlainDriver := (Connection as IZSQLiteConnection).GetPlainDriver;

    NewRowAccessor.SetLong(FAutoColumnIndex, PlainDriver.LastInsertRowId(FHandle));
  end;
end;

// --> ms, 02/11/2005
{**
  Forms a where clause for SELECT statements to calculate default values.
  @param Columns a collection of key columns.
  @param OldRowAccessor an accessor object to old column values.
}
function TZSQLiteCachedResolver.FormCalculateStatement(
  Columns: TObjectList): string;
var
  I: Integer;
  Current: TZResolverParameter;
begin
  Result := '';
  if Columns.Count = 0 then
     Exit;

  for I := 0 to Columns.Count - 1 do
  begin
    Current := TZResolverParameter(Columns[I]);
    if Result <> '' then
      Result := Result + ',';
    if Current.DefaultValue <> '' then
      Result := Result + Current.DefaultValue
    else
      Result := Result + 'NULL';
  end;
  Result := 'SELECT ' + Result;
end;
// <-- ms

end.
