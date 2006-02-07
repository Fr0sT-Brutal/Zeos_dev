{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{ Test Case for Interbase Database Connectivity Classes   }
{                                                         }
{    Copyright (c) 1999-2004 Zeos Development Group       }
{            Written by Sergey Merkuriev                  }
{                                                         }
{*********************************************************}

{*********************************************************}
{ License Agreement:                                      }
{                                                         }
{ This library is free software; you can redistribute     }
{ it and/or modify it under the terms of the GNU Lesser   }
{ General Public License as published by the Free         }
{ Software Foundation; either version 2.1 of the License, }
{ or (at your option) any later version.                  }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ You should have received a copy of the GNU Lesser       }
{ General Public License along with this library; if not, }
{ write to the Free Software Foundation, Inc.,            }
{ 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA }
{                                                         }
{ The project web site is located on:                     }
{   http://www.sourceforge.net/projects/zeoslib.          }
{   http://www.zeoslib.sourceforge.net                    }
{                                                         }
{                                 Zeos Development Group. }
{*********************************************************}

unit ZTestDbcInterbase;

interface

uses
  Classes, TestFramework, ZDbcIntfs, ZDbcInterbase6, ZTestDefinitions,
  ZCompatibility;

type

  {** Implements a test case for class TZAbstractDriver and Utilities. }
  TZTestDbcInterbaseCase = class(TZDbcSpecificSQLTestCase)
  private
    FConnection: IZConnection;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    function GetSupportedProtocols: string; override;
    function GetConnectionUrl: string;

    property Connection: IZConnection read FConnection write FConnection;
  published
    procedure TestConnection;
    procedure TestStatement;
    procedure TestRegularResultSet;
    procedure TestBlobs;
    procedure TestCaseSensitive;
    procedure TestDefaultValues;
    procedure TestDomainValues;
    procedure TestStoredprocedures;
  end;

implementation

uses SysUtils, ZSysUtils, ZTestConsts, ZTestCase;

{ TZTestDbcInterbaseCase }

{**
  Gets an array of protocols valid for this test.
  @return an array of valid protocols
}
function TZTestDbcInterbaseCase.GetSupportedProtocols: string;
begin
  Result := 'interbase,interbase-6.5,interbase-7.2,firebird-1.0,firebird-1.5';
end;

{**
  Gets a connection URL string.
  @return a built connection URL string. 
}
function TZTestDbcInterbaseCase.GetConnectionUrl: string;
begin
  if Port <> 0 then
    Result := Format('zdbc:%s://%s:%d/%s', [Protocol, HostName, Port, Database])
  else Result := Format('zdbc:%s://%s/%s', [Protocol, HostName, Database]);
end;

{**
   Create objects and allocate memory for variables
}
procedure TZTestDbcInterbaseCase.SetUp;
begin
  Connection := CreateDbcConnection;
end;

{**
   Destroy objects and free allocated memory for variables
}
procedure TZTestDbcInterbaseCase.TearDown;
begin
  Connection.Close;
  Connection := nil;
end;

procedure TZTestDbcInterbaseCase.TestConnection;
begin
  CheckEquals(True, Connection.IsReadOnly);
  CheckEquals(True, Connection.IsClosed);
  CheckEquals(True, Connection.GetAutoCommit);
  CheckEquals(Ord(tiNone), Ord(Connection.GetTransactionIsolation));

  CheckEquals(3, (Connection as IZInterbase6Connection).GetDialect);

  { Checks without transactions. }
  Connection.CreateStatement;
  CheckEquals(False, Connection.IsClosed);
  Connection.Commit;
  Connection.Rollback;
  Connection.Close;
  CheckEquals(True, Connection.IsClosed);

  { Checks with transactions. }
  Connection.SetTransactionIsolation(tiSerializable);
  Connection.CreateStatement;
  CheckEquals(False, Connection.IsClosed);
  Connection.Commit;
  Connection.Rollback;
  Connection.Close;
  CheckEquals(True, Connection.IsClosed);
end;

procedure TZTestDbcInterbaseCase.TestStatement;
var
  Statement: IZStatement;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);

  Statement.ExecuteUpdate('UPDATE equipment SET eq_name=eq_name');
  Statement.ExecuteUpdate('SELECT * FROM equipment');

  Check(not Statement.Execute('UPDATE equipment SET eq_name=eq_name'));
  Check(Statement.Execute('SELECT * FROM equipment'));
end;

procedure TZTestDbcInterbaseCase.TestRegularResultSet;
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);
  Statement.SetResultSetType(rtScrollInsensitive);
  Statement.SetResultSetConcurrency(rcReadOnly);

  ResultSet := Statement.ExecuteQuery('SELECT * FROM DEPARTMENT');
  CheckNotNull(ResultSet);
  PrintResultSet(ResultSet, True);
  ResultSet.Close;

  ResultSet := Statement.ExecuteQuery('SELECT * FROM BLOB_VALUES');
  CheckNotNull(ResultSet);
  PrintResultSet(ResultSet, True);
  ResultSet.Close;

  Statement.Close;
end;

procedure TZTestDbcInterbaseCase.TestBlobs;
var
  Connection: IZConnection;
  PreparedStatement: IZPreparedStatement;
  Statement: IZStatement;
  ResultSet: IZResultSet;
  TextStream: TStream;
  ImageStream: TMemoryStream;
  TempStream: TStream;
begin
  Connection := CreateDbcConnection;
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);
  Statement.SetResultSetType(rtScrollInsensitive);
  Statement.SetResultSetConcurrency(rcReadOnly);

  Statement.ExecuteUpdate('DELETE FROM BLOB_VALUES WHERE B_ID='
    + IntToStr(TEST_ROW_ID));

  TextStream := TStringStream.Create('ABCDEFG');
  ImageStream := TMemoryStream.Create;
  ImageStream.LoadFromFile('../../../database/images/zapotec.bmp');

  PreparedStatement := Connection.PrepareStatement(
    'INSERT INTO BLOB_VALUES (B_ID, B_TEXT, B_IMAGE) VALUES(?,?,?)');
  PreparedStatement.SetInt(1, TEST_ROW_ID);
  PreparedStatement.SetAsciiStream(2, TextStream);
  PreparedStatement.SetBinaryStream(3, ImageStream);
  CheckEquals(1, PreparedStatement.ExecuteUpdatePrepared);

  ResultSet := Statement.ExecuteQuery('SELECT * FROM BLOB_VALUES'
    + ' WHERE b_id=' + IntToStr(TEST_ROW_ID));
  CheckNotNull(ResultSet);
  Check(ResultSet.Next);
  CheckEquals(TEST_ROW_ID, ResultSet.GetIntByName('B_ID'));
  TempStream := ResultSet.GetAsciiStreamByName('B_TEXT');
  CheckEquals(TextStream, TempStream);
  TempStream.Free;
  TempStream := ResultSet.GetBinaryStreamByName('B_IMAGE');
  CheckEquals(ImageStream, TempStream);
  TempStream.Free;
  ResultSet.Close;

  TextStream.Free;
  ImageStream.Free;

  Statement.Close;
end;

procedure TZTestDbcInterbaseCase.TestCaseSensitive;
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
  Metadata: IZResultSetMetadata;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);

  ResultSet := Statement.ExecuteQuery('SELECT * FROM "Case_Sensitive"');
  CheckNotNull(ResultSet);
  Metadata := ResultSet.GetMetadata;
  CheckNotNull(Metadata);

  CheckEquals('CS_ID', Metadata.GetColumnName(1));
  CheckEquals(False, Metadata.IsCaseSensitive(1));
  CheckEquals('Case_Sensitive', Metadata.GetTableName(1));

  CheckEquals('Cs_Data1', Metadata.GetColumnName(2));
  CheckEquals(True, Metadata.IsCaseSensitive(2));
  CheckEquals('Case_Sensitive', Metadata.GetTableName(2));

  CheckEquals('cs_data1', Metadata.GetColumnName(3));
  CheckEquals(True, Metadata.IsCaseSensitive(3));
  CheckEquals('Case_Sensitive', Metadata.GetTableName(3));

  CheckEquals('cs data1', Metadata.GetColumnName(4));
  CheckEquals(True, Metadata.IsCaseSensitive(4));
  CheckEquals('Case_Sensitive', Metadata.GetTableName(4));

  ResultSet.Close;
  Statement.Close;
end;

{**
  Runs a test for Interbase default values.
}
procedure TZTestDbcInterbaseCase.TestDefaultValues;
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);
  Statement.SetResultSetType(rtScrollInsensitive);
  Statement.SetResultSetConcurrency(rcUpdatable);

  Statement.ExecuteUpdate('delete from DEFAULT_VALUES');

  ResultSet := Statement.ExecuteQuery('SELECT D_ID,D_FLD1,D_FLD2,D_FLD3,D_FLD4,D_FLD5,D_FLD6 FROM DEFAULT_VALUES');
  CheckNotNull(ResultSet);

  ResultSet.MoveToInsertRow;
  ResultSet.UpdateInt(1, 1);
  ResultSet.InsertRow;

  Check(ResultSet.GetInt(1) <> 0);
  CheckEquals(123456, ResultSet.GetInt(2));
  CheckEquals(123.456, ResultSet.GetFloat(3), 0.001);
  CheckEquals('xyz', ResultSet.GetString(4));
  CheckEquals(EncodeDate(2003, 12, 11), ResultSet.GetDate(5), 0);
  CheckEquals(EncodeTime(23, 12, 11, 0), ResultSet.GetTime(6), 3);
  CheckEquals(EncodeDate(2003, 12, 11) +
    EncodeTime(23, 12, 11, 0), ResultSet.GetTimestamp(7), 3);

  ResultSet.DeleteRow;

  ResultSet.Close;
  Statement.Close;
end;

{**
  Runs a test for Interbase domain fields.
}
procedure TZTestDbcInterbaseCase.TestDomainValues;
var
  Statement: IZStatement;
  ResultSet: IZResultSet;
begin
  Statement := Connection.CreateStatement;
  CheckNotNull(Statement);
  Statement.SetResultSetType(rtScrollInsensitive);
  Statement.SetResultSetConcurrency(rcUpdatable);

  Statement.ExecuteUpdate('delete from DOMAIN_VALUES');

  ResultSet := Statement.ExecuteQuery('SELECT d_id,d_fld1,d_fld2,d_fld3 FROM DOMAIN_VALUES');
  CheckNotNull(ResultSet);

  ResultSet.MoveToInsertRow;
  ResultSet.UpdateInt(1, 1);
  ResultSet.InsertRow;

  Check(ResultSet.GetInt(1) <> 0);
  CheckEquals(123456, ResultSet.GetInt(2));
  CheckEquals(123.456, ResultSet.GetFloat(3), 0.001);
  CheckEquals('xyz', ResultSet.GetString(4));

  ResultSet.Close;
  ResultSet := nil;

  ResultSet := Statement.ExecuteQuery('SELECT d_id,d_fld1,d_fld2,d_fld3 FROM DOMAIN_VALUES');
  CheckNotNull(ResultSet);

  ResultSet.Next;

  Check(ResultSet.GetInt(1) <> 0);
  CheckEquals(123456, ResultSet.GetInt(2));
  CheckEquals(123.456, ResultSet.GetFloat(3), 0.001);
  CheckEquals('xyz', ResultSet.GetString(4));

  ResultSet.Close;
  Statement.Close;
end;

{**
  Runs a test for Interbase stored procedures.
}
procedure TZTestDbcInterbaseCase.TestStoredprocedures;
var
  ResultSet: IZResultSet;
  CallableStatement: IZCallableStatement;
begin
  // Doesn't run with ExecutePrepared. RegisterOutParameter does also not work.
  // Has to be called with an ExecuteQueryPrepared, then has to be fetched and
  // afterwards the Resultes have to be retrieved via result set columns.
  // Resultset must only have one(!) line.
  CallableStatement := Connection.PrepareCallWithParams(
    'PROCEDURE1', nil);
  with CallableStatement do begin
    SetInt(1, 12345);
    ResultSet := ExecuteQueryPrepared;
    with ResultSet do begin
      CheckEquals(True, Next);
      CheckEquals(True, (IsFirst() and IsLast()));
      CheckEquals(12346, GetInt(1));
    end;
  end;
  CallableStatement.Close;

  CallableStatement := Connection.PrepareCallWithParams(
    'PROCEDURE2', nil);
  ResultSet := CallableStatement.ExecuteQueryPrepared;
  with ResultSet do begin
    CheckEquals(True, Next);
    CheckEquals('Computer', GetString(1));
    CheckEquals(True, Next);
    CheckEquals('Laboratoy', GetString(1));
    CheckEquals(True, Next);
    CheckEquals('Radiostation', GetString(1));
    CheckEquals(True, Next);
    CheckEquals('Volvo', GetString(1));
    Close;
  end;
  CallableStatement.Close;
end;

initialization
  TestFramework.RegisterTest(TZTestDbcInterbaseCase.Suite);
end.
