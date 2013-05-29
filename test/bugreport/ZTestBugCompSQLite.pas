{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{       Test Cases for Interbase Component Bug Reports    }
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

unit ZTestBugCompSQLite;

interface

{$I ZBugReport.inc}

uses
  Classes, SysUtils, DB, {$IFDEF FPC}testregistry{$ELSE}TestFramework{$ENDIF},
  ZDataset, ZConnection, ZDbcIntfs, ZSqlTestCase,
  {$IFNDEF LINUX}
    {$IFDEF WITH_VCL_PREFIX}
    Vcl.DBCtrls,
    {$ELSE}
    DBCtrls,
    {$ENDIF}
  {$ENDIF}
  ZCompatibility;
type

  {** Implements a bug report test case for SQLite components. }
  ZTestCompSQLiteBugReport = class(TZAbstractCompSQLTestCase)
  protected
    function GetSupportedProtocols: string; override;
  published
    procedure DummyTest;
  end;

  {** Implements a MBC bug report test case for SQLite components. }
  ZTestCompSQLiteBugReportMBCs = class(TZAbstractCompSQLTestCaseMBCs)
  protected
    function GetSupportedProtocols: string; override;
  published
    procedure Mantis248_TestNonASCIICharSelect;
  end;
implementation

uses
  Variants, ZTestCase, ZTestConsts, ZSqlUpdate;

{ ZTestCompSQLiteBugReport }

function ZTestCompSQLiteBugReport.GetSupportedProtocols: string;
begin
  Result := pl_all_sqlite;
end;

procedure ZTestCompSQLiteBugReport.DummyTest;
begin
  Check(True);
  //Remove me if more tests are available
end;

{ ZTestCompSQLiteBugReportMBCs }
const
  Str1 = 'This license, the Lesser General Public License, applies to some specially designated software packages--typically libraries--of the Free Software Foundation and other authors who decide to use it.  You can use it too, but we suggest you first think ...';
  Str2 = '����� �� �������� ����������� �����, �������� ������� ������������ �������������, �������� ���������� �������������� ������� ��� ������������� ������-������������ �����������. ��� ������������� ���������� (���� ������, ������� ����������, ���������� ...';
  Str3 = '����� �� ��������';
  Str4 = '����������� �����';
  Str5 = '�������� �������';
  Str6 = '������������ �������������';

function ZTestCompSQLiteBugReportMBCs.GetSupportedProtocols: string;
begin
  Result := pl_all_sqlite;
end;

{**
  NUMBER must be froat
}
procedure ZTestCompSQLiteBugReportMBCs.Mantis248_TestNonASCIICharSelect;
const TestRowID = 248;
var
  Query: TZQuery;
  RowCounter: Integer;
  I: Integer;
  procedure InsertValues(TestString: String);
  begin
    Query.ParamByName('s_id').AsInteger := TestRowID+RowCounter;
    Query.ParamByName('s_char').AsString := GetDBTestString(TestString, Connection.DbcConnection.GetConSettings);
    Query.ParamByName('s_varchar').AsString := GetDBTestString(TestString, Connection.DbcConnection.GetConSettings);
    Query.ParamByName('s_nchar').AsString := GetDBTestString(TestString, Connection.DbcConnection.GetConSettings);
    Query.ParamByName('s_nvarchar').AsString := GetDBTestString(TestString, Connection.DbcConnection.GetConSettings);

    Query.ExecSQL;
    inc(RowCounter);
  end;

  procedure CheckColumnValues(TestString: String);
  begin
    CheckEquals(TestString, Query.FieldByName('s_char').AsString, Connection.DbcConnection.GetConSettings);
    CheckEquals(TestString, Query.FieldByName('s_varchar').AsString, Connection.DbcConnection.GetConSettings);
    CheckEquals(TestString, Query.FieldByName('s_nchar').AsString, Connection.DbcConnection.GetConSettings);
    CheckEquals(TestString, Query.FieldByName('s_nvarchar').AsString, Connection.DbcConnection.GetConSettings);
  end;
begin
//??  if SkipForReason(srClosedBug) then Exit;

  Query := CreateQuery;
  Connection.Connect;
  try
    RowCounter := 0;
    Query.SQL.Text := 'Insert into string_values (s_id, s_char, s_varchar, s_nchar, s_nvarchar)'+
      ' values (:s_id, :s_char, :s_varchar, :s_nchar, :s_nvarchar)';
    InsertValues(str2);
    InsertValues(str3);
    InsertValues(str4);
    InsertValues(str5);
    InsertValues(str6);

    Query.SQL.Text := 'select * from string_values where s_id > '+IntToStr(TestRowID-1);
    Query.Open;
    CheckEquals(True, Query.RecordCount = 5);

    Query.SQL.Text := 'select * from string_values where s_char like '+AnsiQuotedStr('%'+GetDBValidString(Str2, Connection.DbcConnection.GetConSettings)+'%', #39);
    Query.Open;
    CheckEquals(True, Query.RecordCount = 1);
    CheckColumnValues(Str2);

    Query.SQL.Text := 'select * from string_values where s_char like '+AnsiQuotedStr('%'+GetDBValidString(Str3, Connection.DbcConnection.GetConSettings)+'%', #39);
    Query.Open;
    CheckEquals(True, Query.RecordCount = 2);
    CheckColumnValues(Str2);
    Query.Next;
    CheckColumnValues(Str3);

    Query.SQL.Text := 'select * from string_values where s_char like '+AnsiQuotedStr('%'+GetDBValidString(Str4, Connection.DbcConnection.GetConSettings)+'%', #39);
    Query.Open;
    CheckEquals(True, Query.RecordCount = 2);
    CheckColumnValues(Str2);
    Query.Next;
    CheckColumnValues(Str4);

    Query.SQL.Text := 'select * from string_values where s_char like '+AnsiQuotedStr('%'+GetDBValidString(Str5, Connection.DbcConnection.GetConSettings)+'%', #39);
    Query.Open;
    CheckEquals(True, Query.RecordCount = 2);
    CheckColumnValues(Str2);
    Query.Next;
    CheckColumnValues(Str5);

    Query.SQL.Text := 'select * from string_values where s_char like '+AnsiQuotedStr('%'+GetDBValidString(Str6, Connection.DbcConnection.GetConSettings)+'%', #39);
    Query.Open;
    CheckEquals(True, Query.RecordCount = 2);
    CheckColumnValues(Str2);
    Query.Next;
    CheckColumnValues(Str6);

  finally
    for i := TestRowID to TestRowID+RowCounter do
    begin
      Query.SQL.Text := 'delete from string_values where s_id = '+IntToStr(i);
      Query.ExecSQL;
    end;
    Query.Free;
  end;
end;

initialization
  RegisterTest('bugreport',ZTestCompSQLiteBugReport.Suite);
  RegisterTest('bugreport',ZTestCompSQLiteBugReportMBCs.Suite);
end.
