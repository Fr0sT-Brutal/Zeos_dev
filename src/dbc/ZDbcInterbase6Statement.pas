{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{         Interbase Database Connectivity Classes         }
{                                                         }
{        Originally written by Sergey Merkuriev           }
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

unit ZDbcInterbase6Statement;

interface

{$I ZDbc.inc}

uses Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils, Types,
  ZDbcIntfs, ZDbcStatement, ZDbcInterbase6, ZDbcInterbase6Utils,
  ZPlainFirebirdInterbaseConstants, ZCompatibility,
  ZDbcLogging, ZVariant, ZMessages;

type

  {** Implements Prepared SQL Statement. }

  { TZInterbase6PreparedStatement }

  TZInterbase6PreparedStatement = class(TZAbstractPreparedStatement)
  private
    FParamSQLData: IZParamsSQLDA;
    FStatusVector: TARRAY_ISC_STATUS;
    FIBConnection: IZInterbase6Connection;
    FCodePageArray: TWordDynArray;

    FResultXSQLDA: IZSQLDA;

    StmtHandle: TISC_STMT_HANDLE;
    StatementType: TZIbSqlStatementType;
  protected
    procedure PrepareInParameters; override;
    procedure BindInParameters; override;
    procedure UnPrepareInParameters; override;
    function CheckInterbase6Error(const Sql: RawByteString = '') : Integer;
  public
    constructor Create(Connection: IZConnection; const SQL: string; Info: TStrings); overload;
    constructor Create(Connection: IZConnection; Info: TStrings); overload;
    destructor Destroy; override;

    procedure Prepare; override;
    procedure Unprepare; override;

    function ExecuteQueryPrepared: IZResultSet; override;
    function ExecuteUpdatePrepared: Integer; override;
    function ExecutePrepared: Boolean; override;
  end;
  TZInterbase6Statement = class(TZInterbase6PreparedStatement);
  TZInterbase6CallableStatement = class(TZAbstractPreparedCallableStatement)
  private
    FParamSQLData: IZParamsSQLDA;
    FResultSQLData: IZSQLDA;
    FStmtHandle: TISC_STMT_HANDLE;
    FStatementType: TZIbSqlStatementType;
    FStatusVector: TARRAY_ISC_STATUS;
    FIBConnection: IZInterbase6Connection;
    FCodePageArray: TWordDynArray;
  protected
    procedure CheckInterbase6Error(const Sql: RawByteString = '');
    function GetProcedureSql(SelectProc: boolean): RawByteString;

    procedure PrepareInParameters; override;
    procedure BindInParameters; override;
    procedure UnPrepareInParameters; override;
  public
    constructor Create(Connection: IZConnection; const SQL: string; Info: TStrings);
    destructor Destroy; override;
    procedure Unprepare; override;

    function ExecuteQueryPrepared: IZResultSet; override;
    function ExecuteUpdatePrepared: Integer; override;
    function ExecutePrepared: Boolean; override;
  end;

implementation

uses ZSysUtils, ZDbcUtils, ZPlainFirebirdDriver, ZDbcInterbase6ResultSet;

{ TZInterbase6PreparedStatement }

procedure TZInterbase6PreparedStatement.PrepareInParameters;
var
  StatusVector: TARRAY_ISC_STATUS;
begin
  With FIBConnection do
    begin
      {create the parameter bind structure}
      FParamSQLData := TZParamsSQLDA.Create(GetPlainDriver, GetDBHandle, GetTrHandle, ConSettings);
      {check dynamic sql}
      GetPlainDriver.isc_dsql_describe_bind(@StatusVector, @StmtHandle, GetDialect,
        FParamSQLData.GetData);
      ZDbcInterbase6Utils.CheckInterbase6Error(GetPlainDriver, StatusVector, ConSettings, lcExecute, ASQL);

      { Resize XSQLDA structure if needed }
      if FParamSQLData.GetData^.sqld > FParamSQLData.GetData^.sqln then
      begin
        FParamSQLData.AllocateSQLDA;
        GetPlainDriver.isc_dsql_describe_bind(@StatusVector, @StmtHandle, GetDialect,FParamSQLData.GetData);
        ZDbcInterbase6Utils.CheckInterbase6Error(GetPlainDriver, StatusVector, ConSettings, lcExecute, ASQL);
      end;

      FParamSQLData.InitFields(True);
    end;
  inherited PrepareInParameters;
end;

procedure TZInterbase6PreparedStatement.BindInParameters;
begin
  BindSQLDAInParameters(ClientVarManager, InParamValues,
    InParamTypes, InParamCount, FParamSQLData, GetConnection.GetConSettings, FCodePageArray);
  inherited BindInParameters;
end;

procedure TZInterbase6PreparedStatement.UnPrepareInParameters;
begin
  if assigned(FParamSQLData) then
    FParamSQLData.FreeParamtersValues;
end;

{**
   Check interbase error status
   @param Sql the used sql tring

   @return Integer - Error Code to test for graceful database disconnection
}
function TZInterbase6PreparedStatement.CheckInterbase6Error(const SQL: RawByteString) : Integer;
begin
  Result := ZDbcInterbase6Utils.CheckInterbase6Error(FIBConnection.GetPlainDriver,
    FStatusVector, ConSettings, lcExecute, SQL);
end;

{**
  Constructs this object and assignes the main properties.
  @param Connection a database connection object.
  @param Handle a connection handle pointer.
  @param Dialect a dialect Interbase SQL must be 1 or 2 or 3.
  @param Info a statement parameters.
}
constructor TZInterbase6PreparedStatement.Create(Connection: IZConnection;
  const SQL: string; Info: TStrings);
begin
  inherited Create(Connection, SQL, Info);

  FIBConnection := Connection as IZInterbase6Connection;
  FCodePageArray := (FIBConnection.GetIZPlainDriver as IZInterbasePlainDriver).GetCodePageArray;
  FCodePageArray[ConSettings^.ClientCodePage^.ID] := ConSettings^.ClientCodePage^.CP; //reset the cp if user wants to wite another encoding e.g. 'NONE' or DOS852 vc WIN1250
  ResultSetType := rtScrollInsensitive;
  StmtHandle := 0;

  Prepare;
end;

constructor TZInterbase6PreparedStatement.Create(Connection: IZConnection;
  Info: TStrings);
begin
  inherited Create(Connection,'', Info);

  FIBConnection := Connection as IZInterbase6Connection;
  FCodePageArray := (FIBConnection.GetIZPlainDriver as IZInterbasePlainDriver).GetCodePageArray;
  FCodePageArray[ConSettings^.ClientCodePage^.ID] := ConSettings^.ClientCodePage^.CP; //reset the cp if user wants to wite another encoding e.g. 'NONE' or DOS852 vc WIN1250
  ResultSetType := rtScrollInsensitive;
  StmtHandle := 0;
end;

destructor TZInterbase6PreparedStatement.Destroy;
begin
  inherited Destroy;
  FreeStatement(FIBConnection.GetPlainDriver, StmtHandle, DSQL_drop);
end;

procedure TZInterbase6PreparedStatement.Prepare;
begin
  StmtHandle := 0;
  with FIBConnection do
  begin
    StatementType := ZDbcInterbase6Utils.PrepareStatement(GetPlainDriver,
      GetDBHandle, GetTrHandle, GetDialect, ASQL, ConSettings, StmtHandle); //allocate handle if required or reuse it

    if StatementType in [stSelect, stExecProc] then
      begin
        FResultXSQLDA := TZSQLDA.Create(GetPlainDriver, GetDBHandle, GetTrHandle, ConSettings);
        PrepareResultSqlData(GetPlainDriver, GetDialect,
          ASQL, StmtHandle, FResultXSQLDA, ConSettings);
      end;
  end;
  CheckInterbase6Error(ASQL);
  inherited Prepare;
end;

procedure TZInterbase6PreparedStatement.Unprepare;
begin
  if StmtHandle <> 0 then //check if prepare did fail. otherwise we unprepare the handle
    FreeStatement(FIBConnection.GetPlainDriver, StmtHandle, DSQL_UNPREPARE); //unprepare avoids new allocation for the stmt handle
  FResultXSQLDA := nil;
  inherited Unprepare;
end;

{**
  Executes any kind of SQL statement.
  Some prepared statements return multiple results; the <code>execute</code>
  method handles these complex statements as well as the simpler
  form of statements handled by the methods <code>executeQuery</code>
  and <code>executeUpdate</code>.
  @see Statement#execute
}
{$HINTS OFF}
function TZInterbase6PreparedStatement.ExecutePrepared: Boolean;
begin
  Result := False;
  if not Prepared then
    Prepare;

  with FIBConnection do
  begin
    BindInParameters;

    if (StatementType = stSelect) then     //AVZ Get many rows - only need to use execute not execute2
      GetPlainDriver.isc_dsql_execute(@FStatusVector, GetTrHandle, @StmtHandle,
        GetDialect, FParamSQLData.GetData)
    else
    begin
      if (FResultXSQLDA = nil) then
        GetPlainDriver.isc_dsql_execute2(@FStatusVector, GetTrHandle, @StmtHandle,
          GetDialect, FParamSQLData.GetData, nil) //not expecting a result
      else
        GetPlainDriver.isc_dsql_execute2(@FStatusVector, GetTrHandle, @StmtHandle,
          GetDialect, FParamSQLData.GetData, FResultXSQLDA.GetData); //expecting a result
    end;

    CheckInterbase6Error(ASQL);

    LastUpdateCount := GetAffectedRows(GetPlainDriver, StmtHandle, StatementType, ConSettings);

    case StatementType of
      stInsert,
      stDelete,
      stUpdate,
      stSelectForUpdate:
        Result := False;
      else
        Result := True;
    end;

    { Create ResultSet if possible else free Statement Handle }
    if (StatementType in [stSelect, stExecProc])
      and (FResultXSQLDA.GetFieldCount <> 0) then
    begin
      LastResultSet := CreateIBResultSet(SQL, Self,
      TZInterbase6XSQLDAResultSet.Create(Self, SQL, StmtHandle,
      FResultXSQLDA, CachedLob, StatementType));
    end
      else
    begin
      LastResultSet := nil;
    end;

    { Autocommit statement. }
    if Connection.GetAutoCommit then
      Connection.Commit;
  end;
  inherited ExecutePrepared;
end;
{$HINTS ON}

{**
  Executes the SQL query in this <code>PreparedStatement</code> object
  and returns the result set generated by the query.

  @return a <code>ResultSet</code> object that contains the data produced by the
    query; never <code>null</code>
}
{$HINTS OFF}
function TZInterbase6PreparedStatement.ExecuteQueryPrepared: IZResultSet;
var
  iError : Integer; //Check for database disconnect AVZ
begin
  if not Prepared then
    Prepare;

  with FIBConnection do
  begin
    try
      if Assigned(FOpenResultSet) then
        IZResultSet(FOpenResultSet).Close;
      FOpenResultSet := nil;

      BindInParameters;

      if (StatementType = stSelect) then     //AVZ Get many rows - only need to use execute not execute2
        GetPlainDriver.isc_dsql_execute(@FStatusVector, GetTrHandle, @StmtHandle,
          GetDialect, FParamSQLData.GetData)
      else
        if (FResultXSQLDA = nil) then
          GetPlainDriver.isc_dsql_execute2(@FStatusVector, GetTrHandle, @StmtHandle,
            GetDialect, FParamSQLData.GetData, nil) //not expecting a result
        else
          GetPlainDriver.isc_dsql_execute2(@FStatusVector, GetTrHandle, @StmtHandle,
            GetDialect, FParamSQLData.GetData, FResultXSQLDA.GetData); //expecting a result

      iError := CheckInterbase6Error(ASQL);

      if (StatementType in [stSelect, stExecProc]) and ( FResultXSQLDA.GetFieldCount <> 0) then
      begin
        if (iError <> DISCONNECT_ERROR) then
          Result := CreateIBResultSet(SQL, Self,
            TZInterbase6XSQLDAResultSet.Create(Self, SQL, StmtHandle,
            FResultXSQLDA, CachedLob, StatementType));
        FOpenResultSet := Pointer(Result);
      end
      else
        if (iError <> DISCONNECT_ERROR) then    //AVZ
          raise EZSQLException.Create(SCanNotRetrieveResultSetData)
        else
          Result := nil;
    except
      on E: Exception do
      begin
        {EH: do not Close the Stmt if execution fails !! This will be done on unprepare}
        //FreeStatement(GetPlainDriver, StmtHandle, DSQL_CLOSE); //AVZ
        raise;
      end;
    end;
  end;
  inherited ExecuteQueryPrepared;
end;
{$HINTS ON}

{**
  Executes the SQL INSERT, UPDATE or DELETE statement
  in this <code>PreparedStatement</code> object.
  In addition,
  SQL statements that return nothing, such as SQL DDL statements,
  can be executed.

  @return either the row count for INSERT, UPDATE or DELETE statements;
  or 0 for SQL statements that return nothing
}
{$HINTS OFF}
function TZInterbase6PreparedStatement.ExecuteUpdatePrepared: Integer;
var
  iError : Integer; //Implementation for graceful disconnect AVZ
begin
  Result := -1;

  if not Prepared then
    Prepare;

  with FIBConnection do
  begin
    BindInParameters;

    GetPlainDriver.isc_dsql_execute(@FStatusVector, GetTrHandle,
      @StmtHandle, GetDialect, FParamSQLData.GetData);
    iError := CheckInterbase6Error(ASQL);

    Result := GetAffectedRows(GetPlainDriver, StmtHandle, StatementType, ConSettings);
    LastUpdateCount := Result;

    case StatementType of
      stCommit, stRollback, stUnknown: Result := -1;
      stSelect: FreeStatement(GetPlainDriver, StmtHandle, DSQL_CLOSE);  //AVZ
    end;

    { Autocommit statement. }
    if Connection.GetAutoCommit and ( StatementType <> stSelect ) then
      Connection.Commit;
  end;
  inherited ExecuteUpdatePrepared;

  //Trail for the disconnection of the database gracefully - AVZ
  if (iError = DISCONNECT_ERROR) then
  begin
    Result := DISCONNECT_ERROR;
  end;

end;
{$HINTS ON}


{ TZInterbase6CallableStatement }

{**
   Check interbase error status
   @param Sql the used sql tring
}
procedure TZInterbase6CallableStatement.CheckInterbase6Error(const Sql: RawByteString);
begin
  ZDbcInterbase6Utils.CheckInterbase6Error(FIBConnection.GetPlainDriver,
    FStatusVector, ConSettings, lcExecute, SQL);
end;

{**
  Constructs this object and assignes the main properties.
  @param Connection a database connection object.
  @param Handle a connection handle pointer.
  @param Dialect a dialect Interbase SQL must be 1 or 2 or 3.
  @param Info a statement parameters.
}
constructor TZInterbase6CallableStatement.Create(Connection: IZConnection;
  const SQL: string; Info: TStrings);
begin
  inherited Create(Connection, SQL, Info);

  FIBConnection := Connection as IZInterbase6Connection;
  FCodePageArray := (FIBConnection.GetIZPlainDriver as IZInterbasePlainDriver).GetCodePageArray;
  ResultSetType := rtScrollInsensitive;
  with FIBConnection do
  begin
    FParamSQLData := TZParamsSQLDA.Create(GetPlainDriver, GetDBHandle,
      GetTrHandle, ConSettings);
    FResultSQLData := TZSQLDA.Create(GetPlainDriver, GetDBHandle,
      GetTrHandle, ConSettings);
  end;
end;

procedure TZInterbase6CallableStatement.PrepareInParameters;
begin
  with FIBConnection do
  begin
    { Prepare statement }
    FStatementType := ZDbcInterbase6Utils.PrepareStatement(GetPlainDriver,
      GetDBHandle, GetTrHandle, GetDialect, ProcSql, ConSettings, FStmtHandle);
    PrepareResultSqlData(GetPlainDriver, GetDialect,
      ProcSql, FStmtHandle, FResultSQLData, ConSettings);
    PrepareParameters(GetPlainDriver, ProcSql, GetDialect, FStmtHandle, FParamSQLData, ConSettings);
  end;
end;

procedure TZInterbase6CallableStatement.BindInParameters;
begin
  BindSQLDAInParameters(ClientVarManager,
    InParamValues, InParamTypes, InParamCount, FParamSQLData, ConSettings, FCodePageArray);
  inherited BindInParameters;
end;

procedure TZInterbase6CallableStatement.UnPrepareInParameters;
begin
  if assigned(FParamSQLData) then
    FParamSQLData.FreeParamtersValues;
end;

procedure TZInterbase6CallableStatement.Unprepare;
begin
  inherited Unprepare;
  FreeStatement(FIBConnection.GetPlainDriver, FStmtHandle, DSQL_unprepare);
  if FStmtHandle <> 0 then // Free statement-hande! On the other hand: Exception!
  begin
    FreeStatement(FIBConnection.GetPlainDriver, FStmtHandle, DSQL_drop);
    FStmtHandle := 0;
  end;
end;

destructor TZInterbase6CallableStatement.Destroy;
begin
  inherited Destroy;
  if FStmtHandle <> 0 then
    FreeStatement(FIBConnection.GetPlainDriver, FStmtHandle, DSQL_drop);
  FResultSQLData := nil;
  FParamSQLData := nil;
end;

{**
  Executes any kind of SQL statement.
  Some prepared statements return multiple results; the <code>execute</code>
  method handles these complex statements as well as the simpler
  form of statements handled by the methods <code>executeQuery</code>
  and <code>executeUpdate</code>.
  @see Statement#execute
}
{$HINTS OFF}
function TZInterbase6CallableStatement.ExecutePrepared: Boolean;
begin
  Result := False;
  with FIBConnection do
  begin
    ProcSql := GetProcedureSql(False);
    BindInParameters;
    DriverManager.LogMessage(lcExecute, ConSettings^.Protocol, ASQL);
    try
      GetPlainDriver.isc_dsql_execute2(@FStatusVector, GetTrHandle, @FStmtHandle,
            GetDialect, FParamSQLData.GetData, Self.FResultSQLData.GetData);
      CheckInterbase6Error(ASQL);

      LastUpdateCount := GetAffectedRows(GetPlainDriver, FStmtHandle, FStatementType, ConSettings);

      case FStatementType of
        stInsert, stDelete, stUpdate, stSelectForUpdate: Result := False;
      else
        Result := True;
      end;

      { Create ResultSet if possible else free Statement Handle, ResultSQlData and
        ParamSqlData }
      if (FStatementType in [stSelect, stExecProc])
        and (FResultSQLData.GetFieldCount <> 0) then
        LastResultSet := TZInterbase6XSQLDAResultSet.Create(Self, SQL,
          FStmtHandle, FResultSQLData, CachedLob, FStatementType)
      else
      begin
        { Fetch data and fill Output params }
          AssignOutParamValuesFromResultSet(TZInterbase6XSQLDAResultSet.Create(
            Self, SQL, FStmtHandle, FResultSQLData, CachedLob, FStatementType),
              OutParamValues, OutParamCount , FDBParamTypes);
        FreeStatement(GetPlainDriver, FStmtHandle, DSQL_CLOSE); //AVZ
        LastResultSet := nil;
      end;

      { Autocommit statement. }
      if Connection.GetAutoCommit then
        Connection.Commit;

    except
      on E: Exception do
      begin
       //FreeStatement(GetPlainDriver, FStmtHandle, DSQL_CLOSE); //AVZ
       raise;
      end;
    end;
  end;
end;
{$HINTS ON}

{**
  Executes the SQL query in this <code>PreparedStatement</code> object
  and returns the result set generated by the query.

  @return a <code>ResultSet</code> object that contains the data produced by the
    query; never <code>null</code>
}
{$HINTS OFF}
function TZInterbase6CallableStatement.ExecuteQueryPrepared: IZResultSet;
begin
  with FIBConnection do
  begin
    ProcSql := GetProcedureSql(True); //Prepares the Statement
    BindInParameters;

    DriverManager.LogMessage(lcExecute, ConSettings^.Protocol, ProcSql);

    if (FStatementType = stSelect) then     //AVZ Get many rows - only need to use execute not execute2
      GetPlainDriver.isc_dsql_execute(@FStatusVector, GetTrHandle, @FStmtHandle,
        GetDialect, FParamSQLData.GetData)
    else
      GetPlainDriver.isc_dsql_execute2(@FStatusVector, GetTrHandle, @FStmtHandle,
        GetDialect, FParamSQLData.GetData, FResultSQLData.GetData);

    CheckInterbase6Error(ProcSql);

    if (FStatementType in [stSelect, stExecProc]) and (FResultSQLData.GetFieldCount <> 0) then
      Result := TZInterbase6XSQLDAResultSet.Create(Self, Self.SQL, FStmtHandle,
        FResultSQLData, CachedLob, FStatementType);
  end;
end;
{$HINTS ON}

{**
  Executes the SQL INSERT, UPDATE or DELETE statement
  in this <code>PreparedStatement</code> object.
  In addition,
  SQL statements that return nothing, such as SQL DDL statements,
  can be executed.

  @return either the row count for INSERT, UPDATE or DELETE statements;
  or 0 for SQL statements that return nothing
}
function TZInterbase6CallableStatement.ExecuteUpdatePrepared: Integer;
begin
  with FIBConnection do
  begin
    ProcSQL := Self.GetProcedureSql(False);
    BindInParameters;

    DriverManager.LogMessage(lcExecute, ConSettings^.Protocol, ProcSQL);

    GetPlainDriver.isc_dsql_execute2(@FStatusVector, GetTrHandle, @FStmtHandle,
      GetDialect, FParamSQLData.GetData, FResultSQLData.GetData);
    CheckInterbase6Error(ProcSql);

    Result := GetAffectedRows(GetPlainDriver, FStmtHandle, FStatementType, ConSettings);
    LastUpdateCount := Result;
    { Fetch data and fill Output params }
      if (FStatementType in [stSelect, stExecProc])
        and (FResultSQLData.GetFieldCount <> 0) then
      begin
        AssignOutParamValuesFromResultSet(TZInterbase6XSQLDAResultSet.Create(Self, SQL, FStmtHandle,
          FResultSQLData, CachedLob, FStatementType), OutParamValues, OutParamCount , FDBParamTypes);
      end
      else
        AssignOutParamValuesFromResultSet(TZInterbase6XSQLDAResultSet.Create(Self, SQL, FStmtHandle,
          FResultSQLData, CachedLob, FStatementType), OutParamValues, OutParamCount , FDBParamTypes);
    { Autocommit statement. }
    if Connection.GetAutoCommit then
      Connection.Commit;
  end;
end;

{**
   Create sql string for calling stored procedure.
   @param SelectProc indicate use <b>EXECUTE PROCEDURE</b> or
    <b>SELECT</b> staement
   @return a Stored Procedure SQL string
}
function TZInterbase6CallableStatement.GetProcedureSql(SelectProc: boolean): RawByteString;

  function GenerateParamsStr(Count: integer): RawByteString;
  var
    I: integer;
  begin
    Result := ''; //init Result -> FPC
    for I := 0 to Count - 1 do
    begin
      if I > 0 then
        Result := Result + ',';
      Result := Result + '?';
    end;
  end;

var
  InParams: RawByteString;
begin
  TrimInParameters;
  InParams := GenerateParamsStr(High(InParamValues) + 1);
  if InParams <> '' then
    InParams := '(' + InParams + ')';

  if SelectProc then
    Result := 'SELECT * FROM ' + ASQL + InParams
  else
    Result := 'EXECUTE PROCEDURE ' + ASQL + InParams;
end;

end.
