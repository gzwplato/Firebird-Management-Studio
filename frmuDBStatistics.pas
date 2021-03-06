{
 * The contents of this file are subject to the InterBase Public License
 * Version 1.0 (the "License"); you may not use this file except in
 * compliance with the License.
 * 
 * You may obtain a copy of the License at http://www.Inprise.com/IPL.html.
 * 
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.  The Original Code was created by Inprise
 * Corporation and its predecessors.
 * 
 * Portions created by Inprise Corporation are Copyright (C) Inprise
 * Corporation. All Rights Reserved.
 * 
 * Contributor(s): ______________________________________.
}

unit frmuDBStatistics;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, ComCtrls, zluibcClasses, IBServices, IB, Grids, frmuDlgClass, resstring;

type
  TfrmDBStatistics = class(TDialog)
    sgOptions: TStringGrid;
    pnlOptionName: TPanel;
    cbOptions: TComboBox;
    lblOptions: TLabel;
    lblDatabaseName: TLabel;
    bvlLine1: TBevel;
    btnOK: TButton;
    btnCancel: TButton;
    stxDatabaseName: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure cbOptionsChange(Sender: TObject);
    procedure cbOptionsDblClick(Sender: TObject);
    procedure cbOptionsExit(Sender: TObject);
    procedure cbOptionsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure sgOptionsDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure sgOptionsSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    Procedure TranslateVisual;override;
  private
    { Private declarations }
    function VerifyInputData(): boolean;
  public
    { Public declarations }
  end;

function DoDBStatistics(const SourceServerNode: TibcServerNode;
                        const CurrSelDatabase: TibcDatabaseNode): integer;

implementation

uses
  zluGlobal, frmuMessage, fileCtrl, IBErrorCodes,
  frmuMain;

{$R *.lfm}

const
  OPTION_NAME_COL = 0;
  OPTION_VALUE_COL = 1;

  STATISTICS_OPTION_ROW = 0;

function DoDBStatistics(const SourceServerNode: TibcServerNode;
  const CurrSelDatabase: TibcDatabaseNode): integer;
var
  frmDBStatistics: TfrmDBStatistics;
  lDBStatisticsData: TStringList;
  lDBStatistics: TIBStatisticalService;
  lDBStatisticsOptions: TStatOptions;

begin
  lDBStatisticsData := TStringList.Create();
  lDBStatistics := TIBStatisticalService.Create(Application.MainForm);
  try
    try
      // assign server details
      lDBStatistics.LoginPrompt := false;
      lDBStatistics.ServerName := SourceServerNode.Server.ServerName;
      lDBStatistics.Protocol := SourceServerNode.Server.Protocol;
      lDBStatistics.Params.Clear;
      lDBStatistics.Params.Assign(SourceServerNode.Server.Params);
      lDBStatistics.Attach();            // try to attach to server
    except                               // if an exception occurs then trap it
      on E:EIBError do                   // and display an error message
      begin
        DisplayMsg(ERR_SERVER_LOGIN, E.Message);
        result := FAILURE;
        if (EIBInterBaseError(E).IBErrorCode = isc_lost_db_connection) or
           (EIBInterBaseError(E).IBErrorCode = isc_unavailable) or
           (EIBInterBaseError(E).IBErrorCode = isc_network_error) then
          frmMain.SetErrorState;
        Exit;
      end;
    end;

    // if successfully attached to server
    if lDBStatistics.Active = true then
    begin
      frmDBStatistics := TfrmDBStatistics.Create(Application.MainForm);
      try
        frmDBStatistics.stxDatabaseName.Caption := MinimizeName (CurrSelDatabase.NodeName,
          frmDBStatistics.stxDatabaseName.Canvas,
          (frmDBStatistics.stxDatabaseName.ClientRect.Left - frmDBStatistics.stxDatabaseName.ClientRect.Right));

        frmDBStatistics.stxDatabaseName.Hint := CurrSelDatabase.NodeName;

        frmDBStatistics.ShowModal;

        if (frmDBStatistics.ModalResult = mrOK) and
           (not frmDBStatistics.GetErrorState) then
        begin
          // repaint screen
          Application.ProcessMessages;
          Screen.Cursor := crHourGlass;

          // assign database details
          lDBStatistics.DatabaseName := CurrSelDatabase.DatabaseFiles.Strings[0];

          lDBStatisticsOptions := [];
          // determine which options have been selected
          if frmDBStatistics.sgOptions.Cells[1,STATISTICS_OPTION_ROW] = LZTDBStatsDataPages then
            Include(lDBStatisticsOptions, DataPages)
          else
            if frmDBStatistics.sgOptions.Cells[1,STATISTICS_OPTION_ROW] = LZTDBStatsHeaderPage then
              Include(lDBStatisticsOptions, HeaderPages)
            else
              if frmDBStatistics.sgOptions.Cells[1,STATISTICS_OPTION_ROW] = LZTDBStatsIndexPages then
                Include(lDBStatisticsOptions, IndexPages)
              else
                if frmDBStatistics.sgOptions.Cells[1,STATISTICS_OPTION_ROW] = LZTDBStatsSystemRelations then
                  Include(lDBStatisticsOptions, SystemRelations);

          // assign validation options
          lDBStatistics.Options := lDBStatisticsOptions;

          // start service
          try
            lDBStatistics.ServiceStart;
            SourceServerNode.OpenTextViewer (lDBStatistics, LZTDBStatsDatabaseStats);
            lDBStatistics.Detach;
          except
            on E: EIBError do
            begin
              DisplayMsg(EIBInterBaseError(E).IBErrorCode, E.Message);
              if (EIBInterBaseError(E).IBErrorCode = isc_lost_db_connection) or
                 (EIBInterBaseError(E).IBErrorCode = isc_unavailable) or
                 (EIBInterBaseError(E).IBErrorCode = isc_network_error) then
                frmMain.SetErrorState;
            end;
          end;
        end;
      except
        on E: Exception do
        begin
          DisplayMsg(ERR_SERVER_SERVICE,E.Message + #13#10 + LZTDBStatsDatabaseStatsConnotDisplayed);
          result := FAILURE;
        end;
      end;
      result := SUCCESS;
    end
    else
      result := FAILURE;
  finally
    Screen.Cursor := crDefault;
    if lDBStatistics.Active then
      lDBStatistics.Detach();
    lDBStatisticsData.Free;
    lDBStatistics.Free;
  end;
end;

procedure TfrmDBStatistics.FormCreate(Sender: TObject);
begin
  inherited;
  sgOptions.DefaultRowHeight := cbOptions.Height;
  cbOptions.Visible := True;
  pnlOptionName.Visible := True;

  sgOptions.RowCount := 1;

  sgOptions.Cells[OPTION_NAME_COL,STATISTICS_OPTION_ROW] := LZTDBStatsShowData;
  sgOptions.Cells[OPTION_VALUE_COL,STATISTICS_OPTION_ROW] := LZTDBStatsAllOptions;

  pnlOptionName.Caption := LZTDBStatsShowData;
  cbOptions.Items.Add(LZTDBStatsAllOptions);
  cbOptions.Items.Add(LZTDBStatsDataPages);
  cbOptions.Items.Add(LZTDBStatsDatabaseLog);
  cbOptions.Items.Add(LZTDBStatsHeaderPage);
  cbOptions.Items.Add(LZTDBStatsIndexPages);
  cbOptions.Items.Add(LZTDBStatsSystemRelations);
  cbOptions.ItemIndex := 0;
end;

procedure TfrmDBStatistics.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TfrmDBStatistics.btnOKClick(Sender: TObject);
begin
  if VerifyInputData() then
    ModalResult := mrOK;
end;

procedure TfrmDBStatistics.cbOptionsChange(Sender: TObject);
begin
  {
  sgOptions.Cells[sgOptions.Col,sgOptions.Row] :=
    cbOptions.Items[cbOptions.ItemIndex];
  cbOptions.Visible := false;
  sgOptions.SetFocus;
  }
end;

procedure TfrmDBStatistics.cbOptionsDblClick(Sender: TObject);
begin
  if (sgOptions.Col = OPTION_VALUE_COL) or (sgOptions.Col = OPTION_NAME_COL) then
  begin
    if cbOptions.ItemIndex = cbOptions.Items.Count - 1 then
      cbOptions.ItemIndex := 0
    else
      cbOptions.ItemIndex := cbOptions.ItemIndex + 1;

    if sgOptions.Col = OPTION_VALUE_COL then
      sgOptions.Cells[sgOptions.Col,sgOptions.Row] := cbOptions.Items[cbOptions.ItemIndex];

    // cbOptions.Visible := True;
    // sgOptions.SetFocus;
  end;
end;

procedure TfrmDBStatistics.cbOptionsExit(Sender: TObject);
var
  lR     : TRect;
  iIndex : Integer;
begin
  iIndex := cbOptions.Items.IndexOf(cbOptions.Text);

  if (iIndex = -1) then
  begin
    MessageDlg(LZTDBStatsInvalidOptionValue, mtError, [mbOK], 0);

    cbOptions.ItemIndex := 0;
    // Size and position the combo box to fit the cell
    lR := sgOptions.CellRect(OPTION_VALUE_COL, sgOptions.Row);
    lR.Left := lR.Left + sgOptions.Left;
    lR.Right := lR.Right + sgOptions.Left;
    lR.Top := lR.Top + sgOptions.Top;
    lR.Bottom := lR.Bottom + sgOptions.Top;
    cbOptions.Left := lR.Left + 1;
    cbOptions.Top := lR.Top + 1;
    cbOptions.Width := (lR.Right + 1) - lR.Left;
    cbOptions.Height := (lR.Bottom + 1) - lR.Top;
    cbOptions.Visible := True;
    cbOptions.SetFocus;
  end
  else if (sgOptions.Col <> OPTION_NAME_COL) then
  begin
    sgOptions.Cells[sgOptions.Col,sgOptions.Row] := cbOptions.Items[iIndex];
  end
  else
  begin
    sgOptions.Cells[OPTION_VALUE_COL,sgOptions.Row] := cbOptions.Items[iIndex];
  end;
end;

procedure TfrmDBStatistics.cbOptionsKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_DOWN) then
    cbOptions.DroppedDown := true;
end;

procedure TfrmDBStatistics.sgOptionsDrawCell(Sender: TObject; ACol,
  ARow: Integer; Rect: TRect; State: TGridDrawState);
const
  INDENT = 2;
var
  lLeft: integer;
  lText: string;
begin
  with sgOptions.canvas do
  begin
    if (ACol = OPTION_VALUE_COL) then
    begin
      font.color := clBlue;
      if brush.color = clHighlight then
        font.color := clWhite;
      lText := sgOptions.Cells[ACol,ARow];
      lLeft := Rect.Left + INDENT;
      TextRect(Rect, lLeft, Rect.top + INDENT, lText);
    end;
  end;
end;

procedure TfrmDBStatistics.sgOptionsSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
var
  lR, lName : TRect;
begin
  cbOptions.Items.Clear;
  cbOptions.Items.Add(LZTDBStatsAllOptions);
  cbOptions.Items.Add(LZTDBStatsDataPages);
  cbOptions.Items.Add(LZTDBStatsDatabaseLog);
  cbOptions.Items.Add(LZTDBStatsHeaderPage);
  cbOptions.Items.Add(LZTDBStatsIndexPages);
  cbOptions.Items.Add(LZTDBStatsSystemRelations);

  pnlOptionName.Caption := sgOptions.Cells[OPTION_NAME_COL, ARow];

  if ACol = OPTION_NAME_COL then
    cbOptions.ItemIndex := cbOptions.Items.IndexOf(sgOptions.Cells[ACol+1,ARow])
  else if ACol = OPTION_VALUE_COL then
    cbOptions.ItemIndex := cbOptions.Items.IndexOf(sgOptions.Cells[ACol,ARow]);

  if ACol = OPTION_NAME_COL then
  begin
    lName := sgOptions.CellRect(ACol, ARow);
    lR := sgOptions.CellRect(ACol + 1, ARow);
  end
  else
  begin
    lName := sgOptions.CellRect(ACol - 1, ARow);
    lR := sgOptions.CellRect(ACol, ARow);
  end;

  // lName := sgOptions.CellRect(ACol, ARow);
  lName.Left := lName.Left + sgOptions.Left;
  lName.Right := lName.Right + sgOptions.Left;
  lName.Top := lName.Top + sgOptions.Top;
  lName.Bottom := lName.Bottom + sgOptions.Top;
  pnlOptionName.Left := lName.Left + 1;
  pnlOptionName.Top := lName.Top + 1;
  pnlOptionName.Width := (lName.Right + 1) - lName.Left;
  pnlOptionName.Height := (lName.Bottom + 1) - lName.Top;
  pnlOptionName.Visible := True;

  // lR := sgOptions.CellRect(ACol, ARow);
  lR.Left := lR.Left + sgOptions.Left;
  lR.Right := lR.Right + sgOptions.Left;
  lR.Top := lR.Top + sgOptions.Top;
  lR.Bottom := lR.Bottom + sgOptions.Top;
  cbOptions.Left := lR.Left + 1;
  cbOptions.Top := lR.Top + 1;
  cbOptions.Width := (lR.Right + 1) - lR.Left;
  cbOptions.Height := (lR.Bottom + 1) - lR.Top;
  cbOptions.Visible := True;
  cbOptions.SetFocus;
end;

function TfrmDBStatistics.VerifyInputData(): boolean;
begin
  result := true;
end;

Procedure TfrmDBStatistics.TranslateVisual;
Begin
  lblDatabaseName.Caption := LZTDBStatsDatabase;
  lblOptions.Caption := LZTDBStatsOption;
  btnOK.Caption := LZTDBStatsOK;
  btnCancel.Caption := LZTDBStatsCancel;
  Self.Caption := LZTDBStatsFormTitle;
End;

end.
