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

unit frmuDBShutdown;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  zluibcClasses, StdCtrls, ComCtrls, ExtCtrls, IBServices, IB, Grids, frmuDlgClass, resstring;

type
  TfrmDBShutdown = class(TDialog)
    bvlLine1: TBevel;
    lblDatabaseName: TLabel;
    lblOptions: TLabel;
    sgOptions: TStringGrid;
    btnOK: TButton;
    btnCancel: TButton;
    stxDatabaseName: TLabel;
    pnlOptionName: TPanel;
    cbOptions: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
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

function DoDBShutdown(const CurrSelServer : TibcServerNode; const CurrSelDatabase: TibcDatabaseNode): integer;

implementation

uses
  zluGlobal, frmuMessage, fileCtrl, IBErrorCodes,
  frmuMain;

{$R *.lfm}

const
  OPTION_NAME_COL = 0;                 // option name column position
  OPTION_VALUE_COL = 1;                // option value column position
  SHUTDOWN_OPTIONS_ROW = 0;            // shutdown option row position
  SHUTDOWN_TIMEOUT_ROW = 1;            // shutdown timeout row position

function DoDBShutdown(const CurrSelServer : TibcServerNode; const CurrSelDatabase: TibcDatabaseNode): integer;
var
  frmDBShutdown : TfrmDBShutdown;
  lConfig       : TIBConfigService;
  lShutdownMode : TShutdownMode;
  iWait         : Integer;
  lReconnect    : Boolean;
begin
  // create form and config service objects
  frmDBShutdown := TfrmDBShutdown.Create(Application.MainForm);
  lConfig := TIBConfigService.Create(Nil);
  lReconnect := False;

  try
    frmDBShutdown.stxDatabaseName.Caption := MinimizeName (CurrSelDatabase.NodeName,
      frmDBShutdown.stxDatabaseName.Canvas,
      (frmDBShutdown.stxDatabaseName.ClientRect.Left - frmDBShutdown.stxDatabaseName.ClientRect.Right));
    frmDBShutdown.stxDatabaseName.Hint := CurrSelDatabase.NodeName;
    frmDBShutdown.ShowModal;

    // show form as modal dialog box
    if (frmDBShutdown.ModalResult = mrOK) and
       (not frmDBShutdown.GetErrorState) then
    begin
      // repaint the screen
      Application.ProcessMessages;
      Screen.Cursor := crHourGlass;

      // attempt to login to server
      try
        lConfig.LoginPrompt:=False;
        lConfig.ServerName:=CurrSelServer.ServerName;
        lConfig.Protocol:=CurrSelServer.Server.Protocol;
        lConfig.DatabaseName := CurrSelDatabase.DatabaseFiles.Strings[0];

        {
        case CurrSelServer.Server.Protocol of
          TCP       : lConfig.DatabaseName := Format('%s:%s',[CurrSelServer.ServerName,CurrSelDatabase.DatabaseFiles.Strings[0]]);
          NamedPipe : lConfig.DatabaseName := Format('\\%s\%s',[CurrSelServer.ServerName,CurrSelDatabase.DatabaseFiles.Strings[0]]);
          SPX       : lConfig.DatabaseName := Format('%s@%s',[CurrSelServer.ServerName,CurrSelDatabase.DatabaseFiles.Strings[0]]);
          Local     : lConfig.DatabaseName := CurrSelDatabase.DatabaseFiles.Strings[0];
        end;
        }

        lConfig.Params.Assign(CurrSelServer.Server.Params);
        lConfig.Attach;
      except                           // if an error occurs
        on E:EIBError do               // trap it and show
        begin                          // error message
          DisplayMsg(ERR_SERVER_LOGIN, E.Message);
          result := FAILURE;           // set result as false
          if (EIBInterBaseError(E).IBErrorCode = isc_lost_db_connection) or
             (EIBInterBaseError(E).IBErrorCode = isc_unavailable) or
             (EIBInterBaseError(E).IBErrorCode = isc_network_error) then
            frmMain.SetErrorState;
          Exit;
        end;
      end;

      // if ConfigService is avtive then
      if lConfig.Active then
      begin
        // assign shutdown mode options
        if frmDBShutdown.sgOptions.Cells[1,0] = LZTDBShutdownDenyNewTransWhileWait then
        begin
          lShutdownMode := DenyAttachment;
        end
        else if frmDBShutdown.sgOptions.Cells[1,0] = LZTDBShutdownDenyNewTransWhileWait then
        begin
          lShutdownMode := DenyTransaction;
        end
        else  // if frmDBShutdown.sgOptions.Cells[1,0] = 'Force shutdown after timeout' then
        begin
          lShutdownMode := Forced;
        end;

        // assign timeout
        iWait := StrToInt(frmDBShutdown.sgOptions.Cells[1,1]);

        // check if IBConsole is connected, if so then close connection to db
        if CurrSelDatabase.Database.TestConnected then
        begin
          CurrSelDatabase.Database.ForceClose;
          lReconnect := True;
        end;

        try
          // try to shutdown the database
          lConfig.ShutdownDatabase(lShutDownMode, iWait);

          // wait while processing
          while (lConfig.IsServiceRunning) and (not gApplShutdown) do
          begin
            Application.ProcessMessages;
            Screen.Cursor := crHourGlass;
          end;

          // if ConfigService is no longer active then detach
          if lConfig.Active then
            lConfig.Detach();

          // try to reconnect to the database using the username
          // and password supplied for the server
          try
            if (lReconnect) and (not CurrSelDatabase.Database.TestConnected) then
            begin
              CurrSelDatabase.Database.Params.Clear;
              CurrSelDatabase.Database.Params.Add(Format('isc_dpb_user_name=%s',[CurrSelServer.UserName]));
              CurrSelDatabase.Database.Params.Add(Format('isc_dpb_password=%s',[CurrSelServer.Password]));
              CurrSelDatabase.Database.Connected := True;
            end;

            DisplayMsg(INF_DATABASE_SHUTDOWN, LZTDBShutdownDatabaseIsShutdownIsCurrentlySingleUserMode);

          // check for an exception
          except                         // if an exception occurs when reattaching then
            on E:EIBInterBaseError do    // show message
            begin
              DisplayMsg(INF_DATABASE_SHUTDOWN, E.Message);
            end;
          end;
        except
          on E:EIBError do
          begin
            DisplayMsg(ERR_DB_SHUTDOWN, E.Message);
            Result := Failure;
            if (EIBInterBaseError(E).IBErrorCode = isc_lost_db_connection) or
               (EIBInterBaseError(E).IBErrorCode = isc_unavailable) or
               (EIBInterBaseError(E).IBErrorCode = isc_network_error) then
              frmMain.SetErrorState;
            Exit;
          end
        end;
        result := SUCCESS;             // set result as true
      end
      else                             // if ConfigService is not active
        result := FAILURE;             // set result as false
    end
    else                               // if form can't be shown
      result := FAILURE;               // set result as false
  finally
    // reconnect to db if it was connected before shutdown occured
    if (lReconnect) and (not CurrSelDatabase.Database.TestConnected) then
    begin
      CurrSelDatabase.Database.Params.Clear;
      CurrSelDatabase.Database.Params.Add(Format('isc_dpb_user_name=%s',[CurrSelServer.UserName]));
      CurrSelDatabase.Database.Params.Add(Format('isc_dpb_password=%s',[CurrSelServer.Password]));
      CurrSelDatabase.Database.Connected := True;
    end;

    Screen.Cursor := crDefault;
    // deallocate memory
    if lConfig.Active then
      lConfig.Detach();
    lConfig.Free;
    frmDBShutdown.Free;
  end;
end;

procedure TfrmDBShutdown.FormCreate(Sender: TObject);
begin
  inherited;
  sgOptions.DefaultRowHeight := cbOptions.Height;
  cbOptions.Visible := True;
  pnlOptionName.Visible := True;

  sgOptions.RowCount := 2;

  sgOptions.Cells[OPTION_NAME_COL,SHUTDOWN_OPTIONS_ROW] := LZTDBShutdownShutdown;
  sgOptions.Cells[OPTION_VALUE_COL,SHUTDOWN_OPTIONS_ROW] := LZTDBShutdownForceShutdownTimeout;

  sgOptions.Cells[OPTION_NAME_COL,SHUTDOWN_TIMEOUT_ROW] := LZTDBShutdownShutdownTimeout;
  sgOptions.Cells[OPTION_VALUE_COL,SHUTDOWN_TIMEOUT_ROW] := '5';

  pnlOptionName.Caption := LZTDBShutdownShutdown;
  cbOptions.Items.Add(LZTDBShutdownDenyNewConnectWaiting);
  cbOptions.Items.Add(LZTDBShutdownDenyNewTransWaiting);
  cbOptions.Items.Add(LZTDBShutdownForceShutdownTimeout);
  cbOptions.ItemIndex := 2;
end;

procedure TfrmDBShutdown.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TfrmDBShutdown.btnOKClick(Sender: TObject);
begin
  if VerifyInputData() then
    ModalResult := mrOK;
end;

procedure TfrmDBShutdown.cbOptionsDblClick(Sender: TObject);
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

procedure TfrmDBShutdown.cbOptionsExit(Sender: TObject);
var
  lR     : TRect;
  iIndex : Integer;
begin
  iIndex := cbOptions.Items.IndexOf(cbOptions.Text);

  if (iIndex = -1) and (sgOptions.Row <> SHUTDOWN_TIMEOUT_ROW) then
  begin
    MessageDlg(LZTDBShutdownInvalidOptionValue, mtError, [mbOK],0);

    cbOptions.ItemIndex := 0;
    //Size and position the combo box to fit the cell
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
  else if (sgOptions.Row = SHUTDOWN_TIMEOUT_ROW) then
  begin
    sgOptions.Cells[OPTION_VALUE_COL,sgOptions.Row] := cbOptions.Text;
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

procedure TfrmDBShutdown.cbOptionsKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_DOWN) then
    cbOptions.DroppedDown := true;
end;

procedure TfrmDBShutdown.sgOptionsDrawCell(Sender: TObject; ACol,
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

procedure TfrmDBShutdown.sgOptionsSelectCell(Sender: TObject; ACol,
  ARow: Integer; var CanSelect: Boolean);
var
  lR, lName : TRect;
begin
  cbOptions.Items.Clear;
  case ARow of
    SHUTDOWN_OPTIONS_ROW:              // if shutdown mode row then
    begin                              // show combo box and populate it
      cbOptions.Style:=csDropDown;
      cbOptions.Items.Add(LZTDBShutdownDenyNewConnectWaiting);
      cbOptions.Items.Add(LZTDBShutdownDenyNewTransWaiting);
      cbOptions.Items.Add(LZTDBShutdownForceShutdownTimeout);
    end;
    SHUTDOWN_TIMEOUT_ROW:              // if timeout row then
    begin                              // show combo as edit box
      cbOptions.Style:=csSimple;
      cbOptions.Text:=sgOptions.Cells[1,SHUTDOWN_TIMEOUT_ROW];
    end;
  end;

  pnlOptionName.Caption := sgOptions.Cells[OPTION_NAME_COL, ARow];

  if ACol = OPTION_NAME_COL then       // copy selected combo item to proper grid location
    cbOptions.ItemIndex := cbOptions.Items.IndexOf(sgOptions.Cells[ACol+1,ARow])
  else if ACol = OPTION_VALUE_COL then
  begin
    cbOptions.ItemIndex := cbOptions.Items.IndexOf(sgOptions.Cells[ACol,ARow]);
    if (cbOptions.ItemIndex = -1) or (ARow = SHUTDOWN_TIMEOUT_ROW) then
      cbOptions.Text := sgOptions.Cells[ACol,ARow];
  end;

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

function TfrmDBShutdown.VerifyInputData(): boolean;
var
  iWait : Integer;
begin
  result := true;                      // assume there are no errors

  // try to convert timeout to a numeric format
  try
    iWait:=StrToInt(sgOptions.Cells[1,1]);
    // check value and make sure it's within range
    if (iWait < 0) or (iWait > 32767) then
    begin                              // show error message
      DisplayMsg(ERR_NUMERIC_VALUE, LZTDBShutdownValueOutOfRange);
      result := false;                 // set result as false
      Exit;
    end;
  except
    on EConvertError do
    begin                              // if not a number, show error message
      DisplayMsg(ERR_NUMERIC_VALUE,'');
      result := false;                 // set result as false
      Exit;
    end;
  end
end;

Procedure TfrmDBShutdown.TranslateVisual;
Begin
  lblDatabaseName.Caption := LZTDBShutdownlblDatabaseName;
  lblOptions.Caption := LZTDBShutdownlblOptions;
  btnOK.Caption := LZTDBShutdownbtnOK;
  btnCancel.Caption := LZTDBShutdownbtnCancel;
  Self.Caption := LZTDBShutdownFormTitle;
End;

end.
