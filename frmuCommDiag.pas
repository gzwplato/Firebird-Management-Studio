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
 * Contributor(s): Krzysztof Golko.
}

unit frmuCommDiag;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, SysUtils,Forms, ExtCtrls, StdCtrls, Classes, Controls, ComCtrls, Dialogs,
  Graphics, zluibcClasses, IB, IBDatabase, IBDatabaseInfo, frmuDlgClass, zluCommDiag, zluSockets, resstring;

type
  TfrmCommDiag = class(TDialog)
    btnSelDB: TButton;
    cbDBServer: TComboBox;
    cbProtocol: TComboBox;
    cbService: TComboBox;
    cbTCPIPServer: TComboBox;
    edtDatabase: TEdit;
    edtPassword: TEdit;
    edtUsername: TEdit;
    gbDBServerInfo: TGroupBox;
    gbDatabaseInfo: TGroupBox;
    gbTCPIPServerInfo: TGroupBox;
    lblDBResults: TLabel;
    lblDatabase: TLabel;
    lblPassword: TLabel;
    lblProtocol: TLabel;
    lblServerName: TLabel;
    lblService: TLabel;
    lblUsername: TLabel;
    lblWinSockResults: TLabel;
    lblWinsockServer: TLabel;
    memDBResults: TMemo;
    memTCPIPResults: TMemo;
    pgcDiagnostics: TPageControl;
    rbLocalServer: TRadioButton;
    rbRemoteServer: TRadioButton;
    tabDBConnection: TTabSheet;
    tabTCPIP: TTabSheet;
    pnlButtonBar: TPanel;
    btnTest: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure btnCancelClick(Sender: TObject);
    procedure btnSelDBClick(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure cbDBServerClick(Sender: TObject);
    procedure rbLocalServerClick(Sender: TObject);
    procedure rbRemoteServerClick(Sender: TObject);
    procedure edtDatabaseChange(Sender: TObject);
    Procedure TranslateVisual;override;
  private
    { Private declarations }
    FProtocols: TStringList;
    FServers: TStringList;
    function VerifyInputData(): boolean;
    procedure PingServer;
    procedure TestDBConnect;
    procedure TestPort(Port : String);
  public
    { Public declarations }
  end;

  function DoDiagnostics(const CurrSelServer: TibcServerNode) : Integer;

const
  Port21     = 0;                      // constants to identify TCP/IP service tests
  PortFTP    = 1;
  Port3050   = 2;
  Portgds_db = 3;
  Ping       = 4;

var
  frmCommDiag: TfrmCommDiag;

implementation

uses
   zluGlobal, zluPersistent, frmuMessage;

{$R *.lfm}

function DoDiagnostics(const CurrSelServer: TibcServerNode): integer;
var
  frmCommDiag: TfrmCommDiag;
begin
  frmCommDiag:= TfrmCommDiag.Create(Application.MainForm);
  try
    // determine if a server is currently selected
    if Assigned(CurrSelServer) then
    begin
      // if a local server is selected then check the local radio button
      if CurrSelServer.Server.Protocol = Local then
      begin
        frmCommDiag.rbLocalServer.Checked := true;
      end
      else
      begin
        // otherwise select the specified protocol of the remote server from the protocol combo box
        // and check the remote radio button
        frmCommDiag.cbDBServer.Text := CurrSelServer.Servername;
        case CurrSelServer.Server.Protocol of
          TCP: frmCommDiag.cbProtocol.ItemIndex := frmCommDiag.cbProtocol.Items.IndexOf(LZTCommDiagcbProtocolItem1);
          NamedPipe: frmCommDiag.cbProtocol.ItemIndex := frmCommDiag.cbProtocol.Items.IndexOf(LZTCommDiagcbProtocolItem2);
          SPX: frmCommDiag.cbProtocol.ItemIndex := frmCommDiag.cbProtocol.Items.IndexOf(LZTCommDiagcbProtocolItem3);
        end;
        frmCommDiag.rbRemoteServer.Checked := true;
      end;
    end
    else                               // if no server selected then assume Local Server
      frmCommDiag.rbLocalServer.Checked := true;
    frmCommDiag.ShowModal;             // show form as modal
    if frmCommDiag.ModalResult = mrOK then
    begin
      result := SUCCESS;
    end
    else
      result := FAILURE;
  finally
    // deallocate memory
    frmCommDiag.Free;
  end;
end;

// if user presses the Cancel button then set the result to mrCancel
procedure TfrmCommDiag.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TfrmCommDiag.btnSelDBClick(Sender: TObject);
var
  lOpenDialog: TOpenDialog;
begin
  lOpenDialog := nil;
  try
  begin
    // create and show open file dialog box
    lOpenDialog := TOpenDialog.Create(self);
    // specify defaul extension and filters
    lOpenDialog.DefaultExt := LZTCommDiagOpenDialogDefaultExt;
    lOpenDialog.Filter := LZTCommDiagOpenDialogFilter;
    // if OK is pressed then extract selected filename
    if lOpenDialog.Execute then
    begin
      edtDatabase.Text := lOpenDialog.Filename;
    end;
  end
  finally
    // deallocate memory
    lOpenDialog.free;
  end;
end;

// if the local radio button is selected then enable and/or disable
// the appropriate controls
procedure TfrmCommDiag.rbLocalServerClick(Sender: TObject);
begin
  if rbLocalServer.Checked then
  begin
    cbDBServer.Text := '';
    cbDBServer.Enabled := false;
    cbProtocol.ItemIndex := -1;
    cbProtocol.Enabled := false;
    cbDBServer.Color := clSilver;
    cbProtocol.Color := clSilver;
    btnSelDB.Enabled := true;
    edtDatabase.Text := '';
    edtUsername.Text := '';
    edtPassword.Text := '';
  end
  else
  begin
    cbDBServer.Enabled := true;
    cbProtocol.Enabled := true;
    cbDBServer.Color := clWindow;
    cbProtocol.Color := clWindow;
    btnSelDB.Enabled := false;
    edtDatabase.Text := '';
    edtUsername.Text := '';
    edtPassword.Text := '';
  end
end;

// if the remote radio button is selected then enable and/or disable
// the appropriate controls
procedure TfrmCommDiag.rbRemoteServerClick(Sender: TObject);
begin
  if rbRemoteServer.Checked then
  begin
    cbDBServer.Enabled := true;
    cbProtocol.Enabled := true;
    cbDBServer.Color := clWindow;
    cbProtocol.Color := clWindow;
    btnSelDB.Enabled := false;
    edtDatabase.Text := '';
    edtUsername.Text := '';
    edtPassword.Text := '';
  end
  else
  begin
    cbDBServer.Enabled := false;
    cbProtocol.Enabled := false;
    cbDBServer.Color := clSilver;
    cbProtocol.Color := clSilver;
    btnSelDB.Enabled := false;
    edtDatabase.Text := '';
    edtUsername.Text := '';
    edtPassword.Text := '';
  end
end;

function TfrmCommDiag.VerifyInputData(): boolean;
begin
  result := true;

  // if the db connection tab is currently active
  if pgcDiagnostics.ActivePage = tabDBConnection then
  begin
    // if the remote radio button is checked
    if rbRemoteServer.Checked then
    begin
      // then make sure a server has been supplied
      if (cbDBServer.Text = '') or (cbDBServer.Text = ' ') then
      begin
        DisplayMsg(ERR_SERVER_NAME,'');
        cbDBServer.SetFocus;
        result := false;
        Exit;
      end;
      // also make sure a network protocol has been selected
      if (cbProtocol.Text = '') or (cbProtocol.Text = ' ') then
      begin
        DisplayMsg(ERR_PROTOCOL,'');
        cbProtocol.SetFocus;
        result := false;
        Exit;
      end;
    end;

    // ensure that a database has been specified
    if (edtDatabase.Text = '') or (edtDatabase.Text = ' ') then
    begin
      DisplayMsg(ERR_DB_ALIAS,'');
      edtDatabase.SetFocus;
      result := false;
      Exit;
    end;

    // ensure that a username has been specified
    if (edtUsername.Text = '') or (edtUsername.Text = ' ') then
    begin
      DisplayMsg(ERR_USERNAME,'');
      edtUsername.SetFocus;
      result := false;
      Exit;
    end;

    // ensure that a password has been specified
    if (edtPassword.Text = '') or (edtPassword.Text = ' ') then
    begin
      DisplayMsg(ERR_PASSWORD,'');
      edtPassword.SetFocus;
      result := false;
      Exit;
    end;
  end

  // otherwise if the TCP/IP tab is active
  else if pgcDiagnostics.ActivePage = tabTCPIP then
  begin
    // ensure that a server is specified
    if (cbTCPIPServer.Text = '') or (cbTCPIPServer.Text = ' ') then
    begin
      DisplayMsg(ERR_SERVER_NAME,'');
      cbTCPIPServer.SetFocus;
      result := false;
      Exit;
    end;

    // also ensure that a service has been selected
    if (cbService.Text = '') or (cbService.Text = ' ') then
    begin
      DisplayMsg(ERR_SERVICE,'');
      cbService.SetFocus;
      result := false;
      Exit;
    end;
  end;
end;

procedure TfrmCommDiag.btnTestClick(Sender: TObject);
begin
  // if all the necessary data has been supplied then proceed
  if VerifyInputData() then
  begin
    // if DB connection is the active page
    if pgcDiagnostics.ActivePage = tabDBConnection then
    begin
      memDBResults.Lines.Clear;        // then clear the database results
      TestDBConnect;                   // perform the database test
    end;

    // if TCP/IP is the active page
    if pgcDiagnostics.ActivePage = tabTCPIP then
    begin
      memTCPIPResults.Lines.Clear;     // then clear the TCP/IP results
      case cbService.ItemIndex of     // determine which service is selected
        Port21     : TestPort(LZTCommDiagcbServiceItem1);   // and perform the TCP/IP test
        PortFTP    : TestPort(LZTCommDiagcbServiceItem2);
        Port3050   : TestPort(LZTCommDiagcbServiceItem3);
        Portgds_db : TestPort(LZTCommDiagcbServiceItem4);
        Ping       : PingServer;
      end;
    end;
  end;
end;

procedure TfrmCommDiag.PingServer;
var
  Ping        : TibcPing;              // Ping
  iMaxRTT     : Integer;               // store maximum round trip time
  iMinRTT     : Integer;               // store minimum round trip time
  iAvgRTT     : Integer;               // stores average round trip time
  fPacketLoss : Real;                  // stores packet loss statistics
  iPackets    : Integer;               // stores number of packets
  iSuccesses  : Integer;               // stores number of successes
  i           : Integer;               // counter
begin
  Ping := Nil;                         // initialize variables
  iMaxRTT:=0;
  iMinRTT:=0;
  iAvgRTT:=0;
  fPacketLoss:=0;
  iSuccesses:=0;
  iPackets:=4;

  Screen.Cursor := crHourGlass;
  try
    Ping := TibcPing.Create;           // create ping object

    with Ping do
    begin
      Host:=cbTCPIPServer.Text;       // set hostname
      Size:=32;                        // set packet size
      TTL:=64;                         // set time to live
      TimeOut:=4000;                   // set timeout
      iMinRTT:=TimeOut div 1000;       // set the minimum RTT to timeout
    end;

    // try to resolve host and get an IP address
    if Ping.ResolveHost then
    begin
      // if the specified host is already an IP address
      if Ping.HostName = ping.HostIP then
      begin
        memTCPIPResults.Lines.Add(LZTCommDiagPinging + ' ' + Ping.HostIP + ' ' + LZTCommDiagWith + ' ' +
          IntToStr(Ping.Size) + ' ' + LZTCommDiagBytesOfData);
      end
      else
      begin
        // if name is resolved then show hostname and IP address
        memTCPIPResults.Lines.Add(LZTCommDiagPinging + ' ' + Ping.HostName + ' [' +
          Ping.HostIP + '] ' + ' ' + LZTCommDiagWith + ' ' + IntToStr(Ping.Size) + ' ' + LZTCommDiagBytesOfData);
      end;
      memTCPIPResults.Lines.Add('');

      // ping server iPacket times
      for i:=0 to iPackets-1 do
      begin
        // ping server
        Ping.Ping;
        with memTCPIPResults.Lines do
        begin
          // if no errors
          if Ping.LastError = 0 then
          begin
            // increment the number of successes
            Inc(iSuccesses);
            // add the round trip time to the average acc
            iAvgRTT:=iAvgRTT + Ping.RTTReply;
            // if RTT larger then maxRTT then store it
            if Ping.RTTReply > iMaxRTT then
              iMaxRTT:=Ping.RTTReply;
            // if RTT less then minRTT then store it
            if Ping.RTTReply < iMinRTT then
              iMinRTT:=Ping.RTTReply;
            // if no error then show reply
            if Ping.LastError = 0 then
            begin
              Add(LZTCommDiagReplyFrom + ' ' + Ping.HostIP + ': ' + LZTCommDiagBytes + '=' +
                IntToStr(Ping.Size) + ' ' + LZTCommDiagTime + '=' + IntToStr(Ping.RTTReply) +
                'ms ' + 'TTL=' + IntToStr(Ping.TTLReply));
            end;
          end
          else                         // if an error occured
          begin
            Add(Ping.VerboseResult);   // then show verbose error message
          end;
        end;
      end;

      if iSuccesses < 1 then           // if there were no successful pings
        iMinRTT:=0;                    // then set minimum RTT to 0

      // calculate the percentage of lost packets
      fPacketLoss:=((iPackets - iSuccesses) / iPackets) * 100;
      // calculate the average round trip times
      iAvgRTT:=iAvgRTT div iPackets;

      // show ping statistics
      with memTCPIPResults.Lines do
      begin
        Add('');
        Add(LZTCommDiagPingStat + ' ' + Ping.HostIP + ':');
        Add('    ' + LZTCommDiagPacketsSend + ' = ' + IntToStr(iPackets) + ', ' + LZTCommDiagPacketsReceived + ' = ' +
          IntToStr(iSuccesses) + ', ' + LZTCommDiagLost + ' = ' + IntToStr(iPackets-iSuccesses) +
          ' (' + FloatToStr(fPacketLoss) + '%),');
        Add(LZTCommDiagApproxRoundTripTimes);
        Add('    ' + LZTCommDiagMin + ' = ' + IntToStr(iMinRTT) + 'ms, ' + LZTCommDiagMax + ' = ' +
          IntToStr(iMaxRTT) + 'ms, ' + LZTCommDiagAvg + ' = ' + IntToStr(iAvgRTT) + 'ms');
      end;
    end
    else                               // if host can't be resolved shot error message
      memTCPIPResults.Lines.add(LZTCommDiagUnknow + ' ' + cbTCPIPServer.Text + '.');
  finally
    // deallocate memory
    Ping.Free;
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmCommDiag.TestDBConnect;
var
  lDatabase : TIBDatabase;
  lProto    : TProtocol;
  iSuccess  : Boolean;
  lDBInfo   : TIBDatabaseInfo;
begin
  lDatabase := Nil;                    // initialize variables
  lDBInfo   := Nil;
  iSuccess  := True;;
  lProto    := Local;

  Screen.Cursor := crHourGlass;

  // if the local radio button is checked then set protocol to local
  if rbLocalServer.Checked or ((cbProtocol.ItemIndex < 0) and
     (rbLocalServer.Checked = False)) then
    lProto:=Local
  else
  begin
    // otherwise determine the specified protocol
    case cbProtocol.ItemIndex of
      0 : lProto:=TCP;
      1 : lProto:=NamedPipe;
      2 : lProto:=SPX;
    end;
  end;

  try
    // create the database object
    lDatabase := TIBDatabase.Create(Self);
    lDBInfo   := TIBDatabaseInfo.Create(Self);
    try
      // setup database path according to the specified protocol
      case lProto of
        TCP       : lDatabase.DatabaseName := Format('%s:%s',[UpperCase(cbDBServer.Text), edtDatabase.Text]);
        NamedPipe : lDatabase.DatabaseName := Format('\\%s\%s',[UpperCase(cbDBServer.Text), edtDatabase.Text]);
        SPX       : lDatabase.DatabaseName := Format('%s@%s',[UpperCase(cbDBServer.Text), edtDatabase.Text]);
        Local     : lDatabase.DatabaseName := edtDatabase.Text;
      end;

      // supply parameters to the database
      lDatabase.LoginPrompt:=False;
      lDatabase.Params.Clear;
      lDatabase.Params.Add(Format('isc_dpb_user_name=%s',[edtUsername.Text]));
      lDatabase.Params.Add(Format('isc_dpb_password=%s',[edtPassword.Text]));
      // connect to database
      lDatabase.Connected:=True;

      // show database name
      lDBInfo.Database := lDatabase;
      memDBResults.Lines.Add(LZTCommDiagAttemptConnect);
      memDBResults.Lines.Add(lDatabase.DatabaseName);
      memDBResults.Lines.Add(Format(LZTCommDiagVersion + ' %s', [lDBInfo.Version]));
      memDBResults.Lines.Add('');

      // test attach - if connected then attach was successful
      if lDatabase.TestConnected then
        memDBResults.Lines.Add(LZTCommDiagAttachPassed);

      try
        // test detach - detach from database
        lDatabase.Connected:=False;
        // if not connected then detach was successful
        if not lDatabase.Connected then
          memDBResults.Lines.Add(LZTCommDiagDetachPassed);
      except
        on E : EIBError do
        begin
          // if an error occurs while detaching then show message
          memDBResults.Lines.Add(LZTCommDiagErrorOccured + ' ' + LZTCommDiagDetaching + '.');
          memDBResults.Lines.Add(LZTCommDiagError + E.Message);
          memDBResults.Lines.Add('');
          iSuccess:=False;             // set success flag to false
        end;
      end;
    except
      on E : EIBError do
      begin
        // if an error occurs while attaching then show message
        memDBResults.Lines.Add(LZTCommDiagErrorOccured + ' ' + LZTCommDiagAttaching + '.');
        memDBResults.Lines.Add(LZTCommDiagError + E.Message);
        iSuccess:=False;               // set success flag to false
      end;
    end;
  finally
    with memDBResults.Lines do
    begin
      if iSuccess then                 // show appropriate message
      begin                            // depending on Success flag
        Add('');
        Add(LZTCommDiagCommTest + ' ' + LZTCommDiagPassed);
      end
      else
        Add(LZTCommDiagCommTest + ' ' + LZTCommDiagFailed);
    end;
    // deallocate memory
    lDatabase.Free;
    lDBInfo.Free;
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmCommDiag.TestPort(Port : String);
var
  Sock     : TibcSocket;               // socket
  iPort    : Integer;                  // port number
  iResolve : Boolean;                  // port name resolution successful
  lService : String;                   // service name
  iSuccess : Boolean;                  // test successful
begin
  Sock := Nil;                         // initialize variables
  iResolve := False;
  iSuccess := True;
  iPort := 3050;
  Screen.Cursor := crHourGlass;

  try
    iPort:=StrToInt(Port);             // convert specified port to a number
    iResolve:=True;                    // set resolution flag to true
  except
    on E : EConvertError do            // if a conversion error occurs then
    begin                              // est conversion flag to false
      iResolve:=False;
    end;
  end;

  try
    Sock:=TibcSocket.Create(Self);     // create socket
    Sock.Host := cbTCPIPServer.Text;  // set hostname
    //Sock.ReportLevel := 1;             // set report level
    Sock.Timeout := 5000;              // set timeout

    with memTCPIPResults.Lines do
    begin
      Add(LZTCommDiagAttempingConnection + ' ' + cbTCPIPServer.Text + '.');
      Add(LZTCommDiagSocketConnectionObtained);
      Add('');

      // if port was resolved to a number then
      if iResolve then
      begin
        Sock.Port:=iPort;              // set the port number
        lService:=Sock.PortName;       // get the port name

        if lService <> '' then
          Add(LZTCommDiagFoundService + ' ''' + lService + ''' ' + LZTCommDiagAtPort + ' ''' + Port + '''')
        else
          Add(LZTCommDiagCouldNotResolveService + ' ''' + lService + ''' ' + LZTCommDiagAtPort + ' ''' + Port + '''');
      end
      // otherwise manually resolve port name to a number
      // and set the port number
      else
      begin
        if Port = LZTCommDiagcbServiceItem2 then
          Sock.Port:=21
        else if Port = LZTCommDiagcbServiceItem4 then
          Sock.Port:=3050;
      end;

      try
        // connect to server via the specified service/port
        Sock.Connect;
      except
        on E : Exception  do
        begin
          // otherwise some other error occured
          Add(LZTCommDiagFailedConnectHost + ' ''' + cbTCPIPServer.Text + ''',');
          Add(LZTCommDiagOnPort + ' ' + Port + '. ' + LZTCommDiagErrorMessage + ' ' + E.Message + '.');
          iSuccess:=False;
        end;
      end;

      // if the connectin is successful
      if Sock.Connected then
      begin
        Add(LZTCommDiagConnectEstablishedToHost + ' ''' + cbTCPIPServer.Text + ''',');
        Add(LZTCommDiagOnPort + ' ' + Port + '.');
        Sock.Disconnect;
      end;
    end;
  finally
    with memTCPIPResults.Lines do
    begin
      Add('');
      if iSuccess then
        Add(LZTCommDiagTCPIPCommTest + ' ' + LZTCommDiagPassed)
      else
        Add(LZTCommDiagTCPIPCommTest + ' ' + LZTCommDiagFailed);
    end;
    // deallocate memory
    Sock.Free;
    Screen.Cursor := crDefault;
  end;
end;

// when the user presses the enter key then execute test task
procedure TfrmCommDiag.FormKeyPress(Sender: TObject; var Key: Char);
begin
  if ord(key)=13 then
  begin
    btnTestClick(sender);
    key:=char(0);
  end;
end;

procedure TfrmCommDiag.FormCreate(Sender: TObject);
var
  lCount : Integer ;
  lServerAliases : TStringList;
  sProps: TibcServerProps;
begin
  inherited;
  FServers := Nil;
  FProtocols := Nil;
  lServerAliases :=Nil;
  pgcDiagnostics.ActivePageIndex := 0;
  try
    FServers := TStringList.Create;
    FProtocols := TStringList.Create;
    lServerAliases := TStringList.Create;

    // if server entries are found
    begin
      // get all server aliases
      PersistentInfo.GetServerAliases(lServerAliases);
      // loop through list of aliases to get server names
      for lCount := 0 to lServerAliases.Count - 1 do
      begin
        PersistentInfo.GetSerVerProps(lServerAliases[lCount], sProps);
          // Only add remote servers (and their protocol) to stringlists
        if sProps.ServerName <> LZTCommDiagsPropsServerNameLocalServer then
      begin
          FServers.Add(sProps.ServerName);
          FProtocols.Add(IntToStr(integer(sProps.Protocol)));
          cbDBServer.Items.Add(sProps.ServerName);
          cbTCPIPServer.Items.Add(sProps.ServerName);
        end;
      end;
    end;

  finally
    lServerAliases.Free;
  end;
end;

// deallocate registry and stringlists when form is closed
procedure TfrmCommDiag.FormDestroy(Sender: TObject);
begin
  FProtocols.Free;
end;

// assigns appropriate protocol for a selected server in the DB connection tab
procedure TfrmCommDiag.cbDBServerClick(Sender: TObject);
begin
  if (FServers.IndexOf(cbDBServer.Text) = -1) then
    cbProtocol.ItemIndex := -1
  else
    cbProtocol.ItemIndex := StrToInt(FProtocols[FServers.IndexOf(cbDBServer.Text)]);
end;

procedure TfrmCommDiag.edtDatabaseChange(Sender: TObject);
begin
  edtDatabase.Hint := edtDatabase.Text;
end;

Procedure TfrmCommDiag.TranslateVisual;
var
  SaveItemIndex: Integer;
Begin
  Self.Caption := LZTCommDiagFormTitle;
  tabDBConnection.Caption := LZTCommDiagtabDBConnectionCaption;
  btnTest.Caption:=LZTCommDiagbtnTestCaption;
  btnCancel.Caption:=LZTCommDiagbtnCancelCaption;
  tabTCPIP.Caption:=LZTCommDiagtabTCPIPCaption;
  gbTCPIPServerInfo.Caption:=LZTCommDiaggbTCPIPServerInfoCaption;
  lblWinsockServer.Caption:=LZTCommDiaglblWinsockServerCaption;
  lblService.Caption:=LZTCommDiaglblServiceCaption;
  lblWinSockResults.Caption:=LZTCommDiaglblWinSockResultsCaption;
  lblDBResults.Caption:=LZTCommDiaglblWinSockResultsCaption;
  gbDBServerInfo.Caption:=LZTCommDiaggbTCPIPServerInfoCaption;
  rbLocalServer.Caption:=LZTCommDiagrbLocalServerCaption;
  rbRemoteServer.Caption:=LZTCommDiagrbRemoteServerCaption;
  lblServerName.Caption:=LZTCommDiaglblServerNameCaption;
  lblProtocol.Caption:=LZTCommDiaglblProtocolCaption;
  gbDatabaseInfo.Caption:=LZTCommDiaggbDatabaseInfoCaption;
  lblDatabase.Caption:=LZTCommDiaglblDatabaseCaption;
  lblUsername.Caption:=LZTCommDiaglblUsernameCaption;
  lblPassword.Caption:=LZTCommDiaglblPasswordCaption;
  btnSelDB.Hint:=LZTCommDiagbtnSelDBHint;
  SaveItemIndex := cbProtocol.ItemIndex;
  cbProtocol.Items.Clear;
  cbProtocol.Items.Add(LZTCommDiagcbProtocolItem1);
  cbProtocol.Items.Add(LZTCommDiagcbProtocolItem2);
  cbProtocol.Items.Add(LZTCommDiagcbProtocolItem3);
  cbProtocol.Items.Add(LZTCommDiagcbProtocolItem4);
  cbProtocol.ItemIndex := SaveItemIndex;
  SaveItemIndex := cbService.ItemIndex;
  cbService.Items.Clear;
  cbService.Items.Add(LZTCommDiagcbServiceItem1);
  cbService.Items.Add(LZTCommDiagcbServiceItem2);
  cbService.Items.Add(LZTCommDiagcbServiceItem3);
  cbService.Items.Add(LZTCommDiagcbServiceItem4);
  cbService.Items.Add(LZTCommDiagcbServiceItem5);
  cbService.ItemIndex := SaveItemIndex;

End;

end.
