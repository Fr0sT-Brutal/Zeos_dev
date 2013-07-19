{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{             Abstract Performance Test Cases             }
{                                                         }
{          Originally written by Sergey Seroukhov         }
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

unit ZPerformanceTestCase;

interface

{$I ZTestFramework.inc}

uses Classes, ZCompatibility, ZTestCase, ZConnection, ZDataset, ZSqlTestCase,
  Contnrs, DB;

type
  {** A method for test set up, run or tear down. }
  TZTestMethod = procedure of object;

  {** Implements a abstract performance test case. }
  TZPerformanceSQLTestCase = class (TZAbstractCompSQLTestCase)
  private
    FSelectedAPIs: TStrings;
    FSelectedTests: TStrings;
    FRecordCount: Integer;
    FRepeatCount: Cardinal;
    FSkipFlag: Boolean;
    FSkipPerformance: Boolean;

    procedure RunSelectedTest(TestName: string; SetUpMethod: TZTestMethod;
      RunTestMethod: TZTestMethod; TearDownMethod: TZTestMethod);

  protected
    procedure LoadConfiguration; override;
    function GetImplementedAPI: string; virtual; abstract;
    function SkipForReason(Reasons: ZSkipReasons): Boolean; override;

    procedure Print(_Message: string); override;
    procedure PrintLn(_Message: string); override;

    { Informational methods. }
    function GetRecordCount: Integer;
    procedure SkipTest;

    { Random values generators. }
    function RandomStr(Length: Integer): string;
    function RandomInt(MinValue, MaxValue: Integer): Integer;
    function RandomFloat(MinValue, MaxValue: Double): Double;

    { Tests table preparation methods. }
    procedure PopulateTable(TableName: string; PrimaryKey: string;
      RecordCount: Integer; ForeignKey: string; ForeignKeyRange: Integer);
    procedure CleanupTable(TableName: string);

    { Implementation of different tests. }
    procedure DefaultSetUpTest; virtual;
    procedure DefaultTearDownTest; virtual;

    procedure SetUpTestConnect; virtual;
    procedure RunTestConnect; virtual;
    procedure TearDownTestConnect; virtual;

    procedure SetUpTestInsert; virtual;
    procedure RunTestInsert; virtual;
    procedure TearDownTestInsert; virtual;

    procedure SetUpTestOpen; virtual;
    procedure RunTestOpen; virtual;
    procedure TearDownTestOpen; virtual;

    procedure SetUpTestFetch; virtual;
    procedure RunTestFetch; virtual;
    procedure TearDownTestFetch; virtual;

    procedure SetUpTestSort; virtual;
    procedure RunTestSort; virtual;
    procedure TearDownTestSort; virtual;

    procedure SetUpTestFilter; virtual;
    procedure RunTestFilter; virtual;
    procedure TearDownTestFilter; virtual;

    procedure SetUpTestUpdate; virtual;
    procedure RunTestUpdate; virtual;
    procedure TearDownTestUpdate; virtual;

    procedure SetUpTestDelete; virtual;
    procedure RunTestDelete; virtual;
    procedure TearDownTestDelete; virtual;

    procedure SetUpTestDirectUpdate; virtual;
    procedure RunTestDirectUpdate; virtual;
    procedure TearDownTestDirectUpdate; virtual;

    procedure SetUpTestLocate; virtual;
    procedure RunTestLocate; virtual;
    procedure TearDownTestLocate; virtual;

    procedure SetUpTestLookup; virtual;
    procedure RunTestLookup; virtual;
    procedure TearDownTestLookup; virtual;

  public
    destructor Destroy; override;

  published
    { DUnit test methods. }
    procedure TestConnect;
    procedure TestInsert;
    procedure TestOpen;
    procedure TestFetch;
    procedure TestSort;
    procedure TestFilter;
    procedure TestUpdate;
    procedure TestDelete;
    procedure TestDirectUpdate;
    procedure TestLocate;
    procedure TestLookup;
  end;

  {** Defines a container for performance test results. }
  TZPerformanceResultItem = class
  private
    FProtocol: String;
    FProperties: String;
    FAPIName: string;
    FTestName: string;
    FTryIndex: Integer;
    FMetric: Double;
  public
    constructor Create(APIName, TestName, Protocol, Properties: string; TryIndex: Integer;
      Metric: Double);
    procedure Normalize(BaseMetric: Double);

    property APIName: string read FAPIName write FAPIName;
    property TestName: string read FTestName write FTestName;
    property TryIndex: Integer read FTryIndex write FTryIndex;
    property Metric: Double read FMetric write FMetric;
    property Protocol: String read FProtocol write FProtocol;
    property Properties: String read FProperties write FProperties;
  end;

  {** Implements a performance result processor. }
  TZPerformanceResultProcessor = class
  private
    FResults: TObjectList;
    FSelectedAPIs: TStrings;
    FSelectedTests: TStrings;
    FProtocols: TStrings;
    FRecordCount: Cardinal;
    FRepeatCount: Cardinal;
    FBaseAPIName: string;
    FDetails: Boolean;
    FOutputType: string;
    FSkipPerformance: Boolean;
  protected
    property Results: TObjectList read FResults write FResults;

    procedure LoadConfiguration;
    function FindResultItem(APIName, TestName: string;
      TryIndex: Integer): TZPerformanceResultItem; overload;
    function FindResultItem(APIName, TestName, Protocol, Properties: string;
      TryIndex: Integer): TZPerformanceResultItem; overload;
    procedure CalculateAverages;
    procedure NormalizeResults;

    procedure PrintPlainResults;
    procedure PrintCSVResults;
    procedure PrintHTMLResults;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterResult(APIName, TestName, Protocol, Properties: String;
      TryIndex: Integer; Metric: Double);
    procedure ProcessResults;
    procedure PrintResults;
    procedure ClearResults;

    property SelectedAPIs: TStrings read FSelectedAPIs;
    property SelectedTests: TStrings read FSelectedTests;
    property SelectedProtocols: TStrings read FProtocols;
    property RepeatCount: Cardinal read FRepeatCount write FRepeatCount;
    property RecordCount: Cardinal read FRecordCount write FRecordCount;
    property BaseAPIName: string read FBaseAPIName write FBaseAPIName;
    property Details: Boolean read FDetails write FDetails;
    property OutputType: string read FOutputType write FOutputType;
  end;

var
  PerformanceResultProcessor: TZPerformanceResultProcessor;

implementation

uses SysUtils, ZSysUtils, ZTestConfig, ZTestConsts, Types;

function ConcatProperties(Properties: TStringDynArray): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to high(Properties) do
    if I = 0 then
      Result := Properties[0]
    else
      Result := Result + ',' +Properties[i];
end;
{ TZPerformanceSQLTestCase }

{**
  Destroys this object and clean ups the memory.
}
destructor TZPerformanceSQLTestCase.Destroy;
begin
  if Assigned(FSelectedAPIs) then
    FSelectedAPIs.Free;
  if Assigned(FSelectedTests) then
    FSelectedTests.Free;

  inherited Destroy;
end;

{**
  Gets a specified record count for test tables.
  @return a specified record count.
}
function TZPerformanceSQLTestCase.GetRecordCount: Integer;
begin
  Result := FRecordCount;
end;

{**
  Loads a configuration from the configuration file.
}
procedure TZPerformanceSQLTestCase.LoadConfiguration;
begin
  inherited LoadConfiguration;

  { Defines a selected APIs }
  if Assigned(FSelectedAPIs) then
    FSelectedAPIs.Free;
  FSelectedAPIs := SplitString(ReadGroupProperty('apis', ''),
    LIST_DELIMITERS);

  { Defines a selected tests }
  if Assigned(FSelectedTests) then
    FSelectedTests.Free;
  FSelectedTests := SplitString(ReadGroupProperty('tests', ''),
    LIST_DELIMITERS);

  { Reads other configuration parameters. }
  FRecordCount := StrToIntDef(ReadGroupProperty('records', ''), 1000);
  FRepeatCount := StrToIntDef(ReadGroupProperty('repeat', ''), 1);
  FSkipPerformance := StrToBoolEx(ReadInheritProperty(SKIP_PERFORMANCE_KEY, TRUE_VALUE));
end;

function TZPerformanceSQLTestCase.SkipForReason(Reasons: ZSkipReasons): Boolean;
begin
  Result := (FSkipPerformance and (srNoPerformance in Reasons));
end;

{**
  Print a string message.
  @param Message a message string.
}
procedure TZPerformanceSQLTestCase.Print(_Message: string);
begin
//  Status(_Message);
  System.Write(_Message);
end;

{**
  Print a string message on a new line.
  @param Message a message string.
}
procedure TZPerformanceSQLTestCase.PrintLn(_Message: string);
begin
//  Status(_Message)
  System.Writeln(_Message);
end;

{**
  Generates a random float value between MinValue and MaxValue.
  @param MinValue a minimum limit value.
  @param MaxValue a maximum limit value.
  @return a random generated value.
}
function TZPerformanceSQLTestCase.RandomFloat(MinValue,
  MaxValue: Double): Double;
begin
  Result := (MinValue * 100 + Random(Trunc((MaxValue - MinValue) * 100))) / 100;
end;

{**
  Generates a random integer value between MinValue and MaxValue.
  @param MinValue a minimum limit value.
  @param MaxValue a maximum limit value.
  @return a random generated value.
}
function TZPerformanceSQLTestCase.RandomInt(MinValue,
  MaxValue: Integer): Integer;
begin
  Result := MinValue + Random(MaxValue - MinValue);
end;

{**
  Generates a random string with the specified length.
  @param Length a string length (default is 32).
  @return a random generated value.
}
function TZPerformanceSQLTestCase.RandomStr(Length: Integer): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  if Length <= 0 then
    Length := 32;
  for I := 1 to Length do
  begin
    C := Chr((Random(Ord('z') - Ord('A') + 1)) + Ord('A'));
    if not CharInSet(C, ['A'..'Z', 'a'..'z']) then
      C := ' ';
    Result := Result + C;
  end;
end;

{**
  Removes all existed rows in the specified table.
  @param TableName a name of the table.
}
procedure TZPerformanceSQLTestCase.CleanupTable(TableName: string);
var
  Query: TZQuery;
begin
  Query := CreateQuery;
  try
    Query.Connection := Connection;
    Query.SQL.Text := Format('DELETE FROM %s', [TableName]);
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

{**
  Populates the data to the specified table.
  @param TableName a name of the table.
  @param PrimaryKey a name of the table primary key
  @param RecordCount a number of records to populate
  @param ForeignKey a name of the foreign key for master-detail relations
    (empty string means no foreign key)
  @param ForeignKeyRange the range of values for the foreign keys - [0..x].
}
procedure TZPerformanceSQLTestCase.PopulateTable(TableName: string;
  PrimaryKey: string; RecordCount: Integer;
  ForeignKey: string; ForeignKeyRange: Integer);
var
  I, Index, Count: Integer;
  Query, Query1: TZQuery;
  CurrentCount: Integer;
  QuerySQL, Fields, Values: string;
begin
  Query := CreateQuery;
  Query1 := CreateQuery;
  try
    Query.ReadOnly := True;

    Query1.Connection := Connection;
    Query1.ReadOnly := True;

    Query1.SQL.Text := Format('SELECT COUNT(*) FROM %s', [TableName]);
    Query1.Open;
    CurrentCount := Query1.Fields[0].AsInteger;
    Query1.Close;

    if RecordCount = CurrentCount then
      Exit;

    Query.SQL.Text := Format('SELECT * FROM %s ORDER BY %s',
      [TableName, PrimaryKey]);
    Query.Open;

    if CurrentCount > RecordCount then
    begin
      QuerySQL := 'DELETE FROM %s WHERE %s=%d';
      Count := CurrentCount - RecordCount;
      Query.Last;
      while not Query.Bof and (Count > 0) do
      begin
        Index := Query.FieldByName(PrimaryKey).AsInteger;
        Query1.SQL.Text := Format(QuerySQL, [TableName, PrimaryKey, Index]);
        Query1.ExecSQL;
        Dec(Count);
        Query.Prior;
      end;
    end
    else
    begin
      QuerySQL := 'INSERT INTO %s (%s) VALUES (%s)';
      Count := RecordCount - CurrentCount;
      Query.First;
      Index := 0;
      while Count > 0 do
      begin
        Inc(Index);

        if not Query.Eof
          and (Query.FieldByName(PrimaryKey).AsInteger = Index) then
        begin
          Query.Next;
          Continue;
        end;

        Fields := '';
        Values := '';
        for I := 0 to Query.FieldCount - 1 do
        begin
          if Fields <> '' then
          begin
            Fields := Fields + ',';
            Values := Values + ',';
          end;

          Fields := Fields + Query.Fields[I].FieldName;

          if UpperCase(PrimaryKey) = UpperCase(Query.Fields[I].FieldName) then
            Values := Values + IntToStr(Index)
          else if UpperCase(ForeignKey) = UpperCase(Query.Fields[I].FieldName) then
            Values := Values + IntToStr(RandomInt(1, ForeignKeyRange))
          else begin
            if Query.Fields[I].DataType in [ftSmallint, ftInteger, ftLargeint] then
              Values := Values + IntToStr(RandomInt(-100, 100))
            else if Query.Fields[I].DataType in [ftString, ftMemo, ftBlob] then
              Values := Values + '''' + RandomStr(10) + ''''
            else
              Values := Values + FloatToSqlStr(RandomFloat(-100, 100));
          end;
        end;
        Query1.SQL.Text := Format(QuerySQL, [TableName, Fields, Values]);
        Query1.ExecSQL;

        Dec(Count);
      end;
    end;

    Query.Close;
  finally
    Query.Free;
    Query1.Free;
  end;
end;

{**
  Runs a selected test.
  @param TestName a name of the test to be runned.
  @param SetUpMethod the method to initialize the test.
  @param RunTestMethod the method to run the test.
  @param TearDownMethod the method to deinitialize the test.
}
procedure TZPerformanceSQLTestCase.RunSelectedTest(TestName: string;
  SetUpMethod, RunTestMethod, TearDownMethod: TZTestMethod);
var
  I: Integer;
  StartTicks: Cardinal;
  StopTicks: Cardinal;
begin
  { Filter tests by selected API and test name. }
  if FSelectedAPIs.IndexOf(GetImplementedAPI) < 0 then
    Exit;
  if FSelectedTests.IndexOf(TestName) < 0 then
    Exit;

  FSkipFlag := False;

  for I := 1 to FRepeatCount do
  begin
    { Initializes the test. }
    SetUpMethod;

    { Runs the test. }
    try
      StartTicks := GetTickCount;
      RunTestMethod;
      StopTicks := GetTickCount;
    finally
    { Deinitializes the test. }
      TearDownMethod;
    end;

    { Registers a performance test result. }
    if not FSkipFlag then
    begin
      PerformanceResultProcessor.RegisterResult(
        GetImplementedAPI, TestName, Self.Protocol, ConcatProperties(Properties), I, StopTicks - StartTicks);
    end else
      Exit;
  end;
end;

{**
  Skips the test where the method is called.
}
procedure TZPerformanceSQLTestCase.SkipTest;
begin
  FSkipFlag := True;
end;

{**
  The default empty Set Up method for all tests.
}
procedure TZPerformanceSQLTestCase.DefaultSetUpTest;
begin
end;

{**
  The default empty Tear Down method for all tests.
}
procedure TZPerformanceSQLTestCase.DefaultTearDownTest;
begin
end;

{**
  The empty Test method for connect test.
}
procedure TZPerformanceSQLTestCase.RunTestConnect;
begin
  SkipTest;
end;

{**
  The empty Test method for delete test.
}
procedure TZPerformanceSQLTestCase.RunTestDelete;
begin
  SkipTest;
end;

{**
  The empty Test method for fetch test.
}
procedure TZPerformanceSQLTestCase.RunTestFetch;
begin
  SkipTest;
end;

{**
  The empty Test method for filter test.
}
procedure TZPerformanceSQLTestCase.RunTestFilter;
begin
  SkipTest;
end;

{**
  The empty Test method for insert test.
}
procedure TZPerformanceSQLTestCase.RunTestInsert;
begin
  SkipTest;
end;

{**
  The empty Test method for open test.
}
procedure TZPerformanceSQLTestCase.RunTestOpen;
begin
  SkipTest;
end;

{**
  The empty Test method for sort test.
}
procedure TZPerformanceSQLTestCase.RunTestSort;
begin
  SkipTest;
end;

{**
  The empty Test method for update test.
}
procedure TZPerformanceSQLTestCase.RunTestUpdate;
begin
  SkipTest;
end;

{**
  The empty Test method for direct update test.
}
procedure TZPerformanceSQLTestCase.RunTestDirectUpdate;
begin
  SkipTest;
end;

{**
  The empty Test method for locate test.
}
procedure TZPerformanceSQLTestCase.RunTestLocate;
begin
  SkipTest;
end;

{**
  The empty Test method for lookup test.
}
procedure TZPerformanceSQLTestCase.RunTestLookup;
begin
  SkipTest;
end;

{**
  The empty Set Up method for connect test.
}
procedure TZPerformanceSQLTestCase.SetUpTestConnect;
begin
  DefaultSetUpTest;
end;

{**
  The empty Set Up method for delete test.
}
procedure TZPerformanceSQLTestCase.SetUpTestDelete;
begin
  PopulateTable(PERFORMANCE_TABLE_NAME, PERFORMANCE_PRIMARY_KEY,
    FRecordCount, '', 0);
  DefaultSetUpTest;
end;

{**
  The empty Set Up method for fetch test.
}
procedure TZPerformanceSQLTestCase.SetUpTestFetch;
begin
  PopulateTable(PERFORMANCE_TABLE_NAME, PERFORMANCE_PRIMARY_KEY,
    FRecordCount, '', 0);
  DefaultSetUpTest;
end;

{**
  The empty Set Up method for filter test.
}
procedure TZPerformanceSQLTestCase.SetUpTestFilter;
begin
  PopulateTable(PERFORMANCE_TABLE_NAME, PERFORMANCE_PRIMARY_KEY,
    FRecordCount, '', 0);
  DefaultSetUpTest;
end;

{**
  The empty Set Up method for insert test.
}
procedure TZPerformanceSQLTestCase.SetUpTestInsert;
begin
  CleanupTable(PERFORMANCE_TABLE_NAME);
  DefaultSetUpTest;
end;

{**
  The empty Set Up method for open test.
}
procedure TZPerformanceSQLTestCase.SetUpTestOpen;
begin
  PopulateTable(PERFORMANCE_TABLE_NAME, PERFORMANCE_PRIMARY_KEY,
    FRecordCount, '', 0);
  DefaultSetUpTest;
end;

{**
  The empty Set Up method for sort test.
}
procedure TZPerformanceSQLTestCase.SetUpTestSort;
begin
  PopulateTable(PERFORMANCE_TABLE_NAME, PERFORMANCE_PRIMARY_KEY,
    FRecordCount, '', 0);
  DefaultSetUpTest;
end;

{**
  The empty Set Up method for update test.
}
procedure TZPerformanceSQLTestCase.SetUpTestUpdate;
begin
  PopulateTable(PERFORMANCE_TABLE_NAME, PERFORMANCE_PRIMARY_KEY,
    FRecordCount, '', 0);
  DefaultSetUpTest;
end;

{**
  The empty Set Up method for direct update test.
}
procedure TZPerformanceSQLTestCase.SetUpTestDirectUpdate;
begin
  PopulateTable(PERFORMANCE_TABLE_NAME, PERFORMANCE_PRIMARY_KEY,
    FRecordCount, '', 0);
  DefaultSetUpTest;
end;

{**
  The empty Set Up method for locate test.
}
procedure TZPerformanceSQLTestCase.SetUpTestLocate;
begin
  PopulateTable(PERFORMANCE_TABLE_NAME, PERFORMANCE_PRIMARY_KEY,
    FRecordCount, '', 0);
  DefaultSetUpTest;
end;

{**
  The empty Set Up method for lookup test.
}
procedure TZPerformanceSQLTestCase.SetUpTestLookup;
begin
  PopulateTable(PERFORMANCE_TABLE_NAME, PERFORMANCE_PRIMARY_KEY,
    FRecordCount, '', 0);
  DefaultSetUpTest;
end;

{**
  The empty Tear Down method for connect test.
}
procedure TZPerformanceSQLTestCase.TearDownTestConnect;
begin
  DefaultTearDownTest;
end;

{**
  The empty Tear Down method for delete test.
}
procedure TZPerformanceSQLTestCase.TearDownTestDelete;
begin
  DefaultTearDownTest;
end;

{**
  The empty Tear Down method for fetch test.
}
procedure TZPerformanceSQLTestCase.TearDownTestFetch;
begin
  DefaultTearDownTest;
end;

{**
  The empty Tear Down method for filter test.
}
procedure TZPerformanceSQLTestCase.TearDownTestFilter;
begin
  DefaultTearDownTest;
end;

{**
  The empty Tear Down method for insert test.
}
procedure TZPerformanceSQLTestCase.TearDownTestInsert;
begin
  DefaultTearDownTest;
end;

{**
  The empty Tear Down method for open test.
}
procedure TZPerformanceSQLTestCase.TearDownTestOpen;
begin
  DefaultTearDownTest;
end;

{**
  The empty Tear Down method for sort test.
}
procedure TZPerformanceSQLTestCase.TearDownTestSort;
begin
  DefaultTearDownTest;
end;

{**
  The empty Tear Down method for update test.
}
procedure TZPerformanceSQLTestCase.TearDownTestUpdate;
begin
  DefaultTearDownTest;
end;

{**
  The empty Tear Down method for direct update test.
}
procedure TZPerformanceSQLTestCase.TearDownTestDirectUpdate;
begin
  DefaultTearDownTest;
end;

{**
  The empty Tear Down method for locate test.
}
procedure TZPerformanceSQLTestCase.TearDownTestLocate;
begin
  DefaultTearDownTest;
end;

{**
  The empty Tear Down method for lookup test.
}
procedure TZPerformanceSQLTestCase.TearDownTestLookup;
begin
  DefaultTearDownTest;
end;

{**
  Performs a connect test.
}
procedure TZPerformanceSQLTestCase.TestConnect;
begin
  if SkipForReason(srNoPerformance) then Exit;
  RunSelectedTest('connect', SetUpTestConnect, RunTestConnect, TearDownTestConnect);
end;

{**
  Performs a delete test.
}
procedure TZPerformanceSQLTestCase.TestDelete;
begin
  if SkipForReason(srNoPerformance) then Exit;
  RunSelectedTest('delete', SetUpTestDelete, RunTestDelete, TearDownTestDelete);
end;

{**
  Performs a fetch test.
}
procedure TZPerformanceSQLTestCase.TestFetch;
begin
  if SkipForReason(srNoPerformance) then Exit;
  RunSelectedTest('fetch', SetUpTestFetch, RunTestFetch, TearDownTestFetch);
end;

{**
  Performs a filter test.
}
procedure TZPerformanceSQLTestCase.TestFilter;
begin
  if SkipForReason(srNoPerformance) then Exit;
  RunSelectedTest('filter', SetUpTestFilter, RunTestFilter, TearDownTestFilter);
end;

{**
  Performs an insert test.
}
procedure TZPerformanceSQLTestCase.TestInsert;
begin
  if SkipForReason(srNoPerformance) then Exit;
  RunSelectedTest('insert', SetUpTestInsert, RunTestInsert, TearDownTestInsert);
end;

{**
  Performs an open test.
}
procedure TZPerformanceSQLTestCase.TestOpen;
begin
  if SkipForReason(srNoPerformance) then Exit;
  RunSelectedTest('open', SetUpTestOpen, RunTestOpen, TearDownTestOpen);
end;

{**
  Performs a sort test.
}
procedure TZPerformanceSQLTestCase.TestSort;
begin
  if SkipForReason(srNoPerformance) then Exit;
  RunSelectedTest('sort', SetUpTestSort, RunTestSort, TearDownTestSort);
end;

{**
  Performs an update test.
}
procedure TZPerformanceSQLTestCase.TestUpdate;
begin
  if SkipForReason(srNoPerformance) then Exit;
  RunSelectedTest('update', SetUpTestUpdate, RunTestUpdate, TearDownTestUpdate);
end;

{**
  Performs a direct update test.
}
procedure TZPerformanceSQLTestCase.TestDirectUpdate;
begin
  if SkipForReason(srNoPerformance) then Exit;
  RunSelectedTest('direct-update', SetUpTestDirectUpdate,
    RunTestDirectUpdate, TearDownTestDirectUpdate);
end;

{**
  Performs a locate test.
}
procedure TZPerformanceSQLTestCase.TestLocate;
begin
  if SkipForReason(srNoPerformance) then Exit;
  RunSelectedTest('locate', SetUpTestLocate, RunTestLocate, TearDownTestLocate);
end;

{**
  Performs a direct update test.
}
procedure TZPerformanceSQLTestCase.TestLookup;
begin
  if SkipForReason(srNoPerformance) then Exit;
  RunSelectedTest('lookup', SetUpTestLookup, RunTestLookup, TearDownTestLookup);
end;

{ TZPerformanceResultItem }

{**
  Constructs a test metric class.
  @param APIName a name of testing API.
  @param TestName a name of specific test.
  @param TryIndex an index of try. 0 is used for average.
  @param Metric a time metric (absolute or relative).
}
constructor TZPerformanceResultItem.Create(APIName, TestName, Protocol, Properties: string;
  TryIndex: Integer; Metric: Double);
begin
  FAPIName := APIName;
  FTestName := TestName;
  FTryIndex := TryIndex;
  FProtocol := Protocol;
  FProperties := Properties;
  if Metric = 0 then
    Metric := 0.1;
  FMetric := Metric;

end;

{**
  Calculates a normalized time metric (relative time metric).
  @param BaseMetric a time metric which is used as 100%.
}
procedure TZPerformanceResultItem.Normalize(BaseMetric: Double);
begin
  if BaseMetric > 0 then
    FMetric := FMetric * 100 / BaseMetric
  else FMetric := -1;
end;

{ TZPerformanceResultProcessor }

{**
  Creates a performance result processor object.
}
constructor TZPerformanceResultProcessor.Create;
begin
  FResults := TObjectList.Create;
  FSelectedAPIs := TStringList.Create;
  FSelectedTests := TStringList.Create;
  FProtocols := TStringList.Create;
end;

{**
  Destroys this object and cleanups the memory.
}
destructor TZPerformanceResultProcessor.Destroy;
var I: Integer;
begin
  FResults.Free;
  FSelectedAPIs.Free;
  FSelectedTests.Free;
  for i := 0 to FProtocols.Count -1 do
    TStringList(FProtocols.Objects[i]).Free;
  FProtocols.Free;
  inherited Destroy;
end;

{**
  Loads a configuration from the configuration file.
}
procedure TZPerformanceResultProcessor.LoadConfiguration;
begin
  { Defines a selected APIs }
  if Assigned(FSelectedAPIs) then
    FSelectedAPIs.Free;
  FSelectedAPIs := SplitString(TestConfig.ReadProperty(
    TestGroup, 'apis', ''), LIST_DELIMITERS);

  { Defines a selected tests }
  if Assigned(FSelectedTests) then
    FSelectedTests.Free;
  FSelectedTests := SplitString(TestConfig.ReadProperty(
    TestGroup, 'tests', ''), LIST_DELIMITERS);

  { Reads other configuration parameters. }
  FRepeatCount := StrToIntDef(TestConfig.ReadProperty(
    TestGroup, 'repeat', ''), 1);
  FRecordCount := StrToIntDef(TestConfig.ReadProperty(
    TestGroup, 'records', ''), 1000);
  FDetails := StrToBoolEx(TestConfig.ReadProperty(
    TestGroup, 'printdetails', FALSE_VALUE));
  FBaseAPIName := TestConfig.ReadProperty(TestGroup, 'baseapi', '');
  FOutputType := TestConfig.ReadProperty(TestGroup, 'output', 'plain');
  FSkipPerformance := StrToBoolEx(TestConfig.ReadProperty(TestGroup, SKIP_PERFORMANCE_KEY, TRUE_VALUE));
end;

{**
  Finds a performance result item by specified criteria.
  @param APIName a name of API.
  @param TestName a name of specific test.
  @param TryIndex an index of try.
  @returns a found object or <code>nil</code> otherwise.
}
function TZPerformanceResultProcessor.FindResultItem(APIName,
  TestName: string; TryIndex: Integer): TZPerformanceResultItem;
var
  I: Integer;
  Current: TZPerformanceResultItem;
begin
  Result := nil;
  for I := 0 to Results.Count - 1 do
  begin
    Current := TZPerformanceResultItem(Results[I]);
    if (Current.APIName = APIName) and (Current.TestName = TestName)
      and (Current.TryIndex = TryIndex) then
    begin
      Result := Current;
      Break;
    end;
  end;
end;

function TZPerformanceResultProcessor.FindResultItem(APIName,
  TestName, Protocol, Properties: string; TryIndex: Integer): TZPerformanceResultItem;
var
  I: Integer;
  Current: TZPerformanceResultItem;
begin
  Result := nil;
  for I := 0 to Results.Count - 1 do
  begin
    Current := TZPerformanceResultItem(Results[I]);
    if (Current.APIName = APIName) and (Current.TestName = TestName)
      and (Current.Protocol = Protocol) and (Current.Properties = Properties)
      and (Current.TryIndex = TryIndex) then
    begin
      Result := Current;
      Break;
    end;
  end;
end;

{**
  Calculates average time metrics for test results.
}
procedure TZPerformanceResultProcessor.CalculateAverages;
var
  I, J, M, N, K: Integer;
  Count: Integer;
  AverageMetric, AverageMetricToal, AverageMetricProtcol: Double;
  Current: TZPerformanceResultItem;
begin
  AverageMetricToal := 0;
  for I := 0 to SelectedAPIs.Count - 1 do
  begin
    Count := 0;
    for J := 0 to SelectedTests.Count - 1 do
    begin
      AverageMetric := 0;
      for K := 1 to RepeatCount do
      begin
        for M := 0 to FProtocols.Count-1 do
        begin
          AverageMetricProtcol := 0;
          for N := 0 to TStringList(FProtocols.Objects[M]).Count -1 do
          begin
            Current := Self.FindResultItem(SelectedAPIs[I], SelectedTests[J], FProtocols[M], TStringList(FProtocols.Objects[M])[N], K);
            if Current <> nil then
            begin
              Inc(Count);
              AverageMetricToal := AverageMetricToal + Current.Metric;
              AverageMetricProtcol := AverageMetricProtcol + Current.Metric;
              AverageMetric := AverageMetric + Current.Metric;
              RegisterResult(Current.APIName, Current.TestName, Current.Protocol, Current.Properties, K, Current.Metric);
            end;
          end;
          if TStringList(FProtocols.Objects[M]).Count > 0 then
            AverageMetricProtcol := AverageMetricProtcol / TStringList(FProtocols.Objects[M]).Count
          else AverageMetricProtcol := -1;
          RegisterResult(SelectedAPIs[I], SelectedTests[J], FProtocols[M], 'All properties', 0, AverageMetricProtcol);
        end;
        if Count > 0 then
          AverageMetric := AverageMetric / Count
        else AverageMetric := -1;
        RegisterResult(SelectedAPIs[I], SelectedTests[J], 'All protocols of '+SelectedTests[J], 'All properties', 0, AverageMetric);
      end;
    end;
  end;
  RegisterResult('All Apis', 'All tests', 'All protocols', 'All properties', 0, AverageMetricToal);
end;

{**
  Normalizes performance results based on specified API.
}
procedure TZPerformanceResultProcessor.NormalizeResults;
var
  I, J, K: Integer;
  BaseMetric: Double;
  Current: TZPerformanceResultItem;
begin
  if BaseAPIName = '' then Exit;
  
  for I := 0 to SelectedTests.Count - 1 do
  begin
    Current := FindResultItem(BaseAPIName, SelectedTests[I], 0);
    if Current <> nil then
      BaseMetric := Current.Metric
    else BaseMetric := -1;

    for J := 0 to SelectedAPIs.Count - 1 do
    begin
      for K := 0 to RepeatCount do
      begin
        Current := Self.FindResultItem(SelectedAPIs[J], SelectedTests[I], K);
        if Current <> nil then
          Current.Normalize(BaseMetric);
      end;
    end;
  end;
end;

{**
  Prints performance test results in CSV format.
}
procedure TZPerformanceResultProcessor.PrintCSVResults;
var
  I, J, K: Integer;
  TryIndex: Integer;
  StartTry: Integer;
  Current: TZPerformanceResultItem;
  Units: string;
begin
  if BaseAPIName = '' then
    Units := 'ms'
  else Units := '%';

  Write('API');
  if Details then
    Write(',TRY');
  for I := 0 to SelectedTests.Count - 1 do
    Write(',', UpperCase(SelectedTests[I]));
  WriteLn;

  for I := 0 to SelectedAPIs.Count - 1 do
  begin
    if Details then
      StartTry := 1
    else StartTry := RepeatCount + 1;

    for J := StartTry to RepeatCount + 1 do
    begin
      Write(UpperCase(SelectedAPIs[I]));
      if J > Integer(RepeatCount) then
      begin
        if Details then
          Write(',Average');
        TryIndex := 0;
      end
      else
      begin
        if Details then
          Write(',', J);
        TryIndex := J;
      end;

      for K := 0 to SelectedTests.Count - 1 do
      begin
        Current := Self.FindResultItem(SelectedAPIs[I], SelectedTests[K],
          TryIndex);
        if (Current <> nil) and (Current.Metric >= 0) then
          Write(',', Format('%.2f', [Current.Metric]))
        else Write(',');
      end;

      WriteLn;
    end
  end;
end;

{**
  Prints performance test results in HTML format.
}
procedure TZPerformanceResultProcessor.PrintHTMLResults;
var
  I, J, K: Integer;
  TryIndex: Integer;
  StartTry: Integer;
  Current: TZPerformanceResultItem;
  Units: string;
begin
  if BaseAPIName = '' then
    Units := 'ms'
  else Units := '%';

  WriteLn('<table border=1>');
  WriteLn('  <tr>');
  Write('    <th>API</th>');
  if Details then
    Write('<th>TRY</th>');
  for I := 0 to SelectedTests.Count - 1 do
    Write('<th>', UpperCase(SelectedTests[I]), '</th>');
  WriteLn;
  WriteLn('  </tr>');

  for I := 0 to SelectedAPIs.Count - 1 do
  begin
    if Details then
      StartTry := 1
    else StartTry := RepeatCount + 1;

    WriteLn('  <tr>');
    Write('    <td rowspan=', Integer(RepeatCount) + 2 - StartTry , '>',
      UpperCase(SelectedAPIs[I]), '</td>');

    for J := StartTry to RepeatCount + 1 do
    begin
      if J > StartTry then
      begin
        WriteLn('  <tr>');
        Write('    ');
      end;

      if J > Integer(RepeatCount) then
      begin
        if Details then
          Write('<th>Average</th>');
        TryIndex := 0;
      end
      else
      begin
        if Details then
          Write('<td>', J, '</td>');
        TryIndex := J;
      end;

      for K := 0 to SelectedTests.Count - 1 do
      begin
        Current := Self.FindResultItem(SelectedAPIs[I], SelectedTests[K],
          TryIndex);
        if (Current <> nil) and (Current.Metric >= 0) then
        begin
          if TryIndex = 0 then
            Write('<th>', Format('%.2f %s', [Current.Metric, Units]), '</th>')
          else
            Write('<td>', Format('%.2f %s', [Current.Metric, Units]), '</td>');
        end else
          Write('<td>&nbsp;</td>');
      end;

      WriteLn;
      WriteLn('  </tr>');
    end
  end;
  WriteLn('</table>');
end;

{**
  Prints performance test results in plain (regular) format.
}
procedure TZPerformanceResultProcessor.PrintPlainResults;
var
  I, J, N, M, K: Integer;
  Current: TZPerformanceResultItem;
  Units: string;
begin
  if BaseAPIName = '' then
    Units := 'ms'
  else Units := '%';

  for I := 0 to SelectedAPIs.Count - 1 do
  begin
    for J := 0 to SelectedTests.Count - 1 do
    begin
      WriteLn(Format('Running API: %s, Test: %s, Records: %d',
        [UpperCase(SelectedAPIs[I]), UpperCase(SelectedTests[J]), RecordCount]));

      for N := 0 to FProtocols.Count -1 do
      begin
        WriteLn('');
        WriteLn(' Used protocol: '+FProtocols[n]);
        WriteLn('');
        Current := Self.FindResultItem(SelectedAPIs[I], SelectedTests[J], Fprotocols[n], 'All properties', 0);
        if (Current <> nil) and (Current.Metric >= 0) then
          WriteLn(Format('Try total %d - %.2f %s(%s)', [TStringList(FProtocols.Objects[N]).Count-1, Current.Metric, Units, 'All properties']))
        else
          WriteLn(Format('Try total %d - absent', [0]));
        if Details then
          for K := 1 to RepeatCount do
          begin
            for M := 0 to TStringList(FProtocols.Objects[N]).Count -2 do
            begin
              Current := Self.FindResultItem(SelectedAPIs[I], SelectedTests[J], Fprotocols[n], TStringList(FProtocols.Objects[N])[M], K);
              if (Current <> nil) and (Current.Metric >= 0) then
                WriteLn(Format('Try %d - %.2f %s(%s)', [K, Current.Metric, Units, TStringList(FProtocols.Objects[N])[M]]))
              else
                WriteLn(Format('Try %d - absent', [K]));
            end;
          end;
      end;
      Current := FindResultItem(SelectedAPIs[I], SelectedTests[J], 'All protocols of '+SelectedTests[J], 'All properties', 0);
      if (Current <> nil) and (Current.Metric >= 0) then
        WriteLn(Format('  Average - %.2f %s', [Current.Metric, Units]))
      else WriteLn('  Average - absent');
      WriteLn('');
    end;
  end;
  Current := FindResultItem('All Apis', 'All tests', 'All protocols', 'All properties', 0);
  if (Current <> nil) and (Current.Metric >= 0) then
    WriteLn(Format('  Average - %.2f %s', [Current.Metric, Units]))
  else WriteLn('  Average - absent');
  WriteLn('');
end;

{**
  Registers a particular performance test result.
  @param APIName a name of tested API.
  @param TestName a name of specified test.
  @param TryIndex an index of try.
  @param Metric a time metric.
}
procedure TZPerformanceResultProcessor.RegisterResult(APIName, TestName, Protocol, Properties: String;
   TryIndex: Integer; Metric: Double);
var iProt: Integer;
begin
  Results.Add(TZPerformanceResultItem.Create(APIName, TestName,
    Protocol, Properties, TryIndex, Metric));
  iProt := FProtocols.IndexOf(Protocol);
  if iProt = -1 then
    iProt := FProtocols.AddObject(Protocol, TStringList.Create);
  if TStringList(FProtocols.Objects[iProt]).IndexOf(Properties) = -1 then
    TStringList(FProtocols.Objects[iProt]).Add(Properties);
end;

{**
  Prints performance test results in specific format.
}
procedure TZPerformanceResultProcessor.PrintResults;
var
  Output: string;
begin
  if FSkipPerformance then Exit;

  Output := UpperCase(OutputType);
  if Output = 'CSV' then
    PrintCSVResults
  else if Output = 'HTML' then
    PrintHTMLResults
  else PrintPlainResults;
end;

{**
  Processes performance results.
}
procedure TZPerformanceResultProcessor.ProcessResults;
begin
  if FSkipPerformance then Exit;

  CalculateAverages;
  if BaseAPIName <> '' then
    NormalizeResults;
end;

{**
  Clears all registered results.
}
procedure TZPerformanceResultProcessor.ClearResults;
begin
  Results.Clear;
end;

initialization
  PerformanceResultProcessor := TZPerformanceResultProcessor.Create;
  PerformanceResultProcessor.LoadConfiguration;
finalization
  if Assigned(PerformanceResultProcessor) then
    PerformanceResultProcessor.Free;
end.

