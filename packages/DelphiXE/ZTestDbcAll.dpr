{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{      Test Suite for Database Connectivity Classes       }
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

program ZTestDbcAll;

{$I ..\..\test\dbc\ZDbc.inc}

{$IFNDEF TESTGUI}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  TestFrameWork,
  TextTestRunner,
  ZTestConfig,
  ZSqlTestCase,
  ZTestDbcASA in '..\..\test\dbc\ZTestDbcASA.pas',
  ZTestDbcASAMetadata in '..\..\test\dbc\ZTestDbcASAMetadata.pas',
  ZTestDbcCache in '..\..\test\dbc\ZTestDbcCache.pas',
  ZTestDbcCachedResultSet in '..\..\test\dbc\ZTestDbcCachedResultSet.pas',
  ZTestDbcGeneric in '..\..\test\dbc\ZTestDbcGeneric.pas',
  ZTestDbcInterbase in '..\..\test\dbc\ZTestDbcInterbase.pas',
  ZTestDbcInterbaseMetadata in '..\..\test\dbc\ZTestDbcInterbaseMetadata.pas',
  ZTestDbcMetadata in '..\..\test\dbc\ZTestDbcMetadata.pas',
  ZTestDbcMsSql in '..\..\test\dbc\ZTestDbcMsSql.pas',
  ZTestDbcMySql in '..\..\test\dbc\ZTestDbcMySql.pas',
  ZTestDbcMySqlMetadata in '..\..\test\dbc\ZTestDbcMySqlMetadata.pas',
  ZTestDbcOracle in '..\..\test\dbc\ZTestDbcOracle.pas',
  ZTestDbcPostgreSql in '..\..\test\dbc\ZTestDbcPostgreSql.pas',
  ZTestDbcPostgreSqlMetadata in '..\..\test\dbc\ZTestDbcPostgreSqlMetadata.pas',
  ZTestDbcResolver in '..\..\test\dbc\ZTestDbcResolver.pas',
  ZTestDbcResultSet in '..\..\test\dbc\ZTestDbcResultSet.pas',
  ZTestDbcResultSetMetadata in '..\..\test\dbc\ZTestDbcResultSetMetadata.pas',
  ZTestDbcSqLite in '..\..\test\dbc\ZTestDbcSqLite.pas',
  ZTestDbcUtils in '..\..\test\dbc\ZTestDbcUtils.pas';

begin
  TestGroup := DBC_TEST_GROUP;
  RebuildTestDatabases;
{$IFDEF TESTGUI}
  GUITestRunner.RunRegisteredTests;
{$ELSE}
  TextTestRunner.RunRegisteredTests;
{$ENDIF}
end.
