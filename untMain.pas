{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

 Author: Boban Spasic

}

unit untMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, ShellCtrls,
  ComCtrls, Grids, JvRollOut, untUtils, untDX7Voice, untDX7Bank, untDXUtils,
  IniFiles, LResources, LCLType, FileUtil, untPopUp;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    ilToolbar: TImageList;
    OpenDialog1: TOpenDialog;
    pnRight: TPanel;
    roLeft: TJvRollOut;
    roRight: TJvRollOut;
    pnLeft: TPanel;
    SaveDialog1: TSaveDialog;
    StatusBar: TStatusBar;
    sgLeft: TStringGrid;
    sgRight: TStringGrid;
    stvLeft: TShellTreeView;
    Splitter: TSplitter;
    tbRight: TToolBar;
    tbtNew: TToolButton;
    tbtLoad: TToolButton;
    tbtSave: TToolButton;
    tbtSaveAs: TToolButton;
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure sgLeftClick(Sender: TObject);
    procedure sgLeftDragDrop(Sender, Source: TObject; X, Y: integer);
    procedure sgLeftDragOver(Sender, Source: TObject; X, Y: integer;
      State: TDragState; var Accept: boolean);
    procedure sgRightDragDrop(Sender, Source: TObject; X, Y: integer);
    procedure sgRightDragOver(Sender, Source: TObject; X, Y: integer;
      State: TDragState; var Accept: boolean);
    procedure sgRightEditingDone(Sender: TObject);
    procedure sgSelection(Sender: TObject; aCol, aRow: integer);
    procedure sgMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: integer);
    procedure stvClick(Sender: TObject);
    procedure kpDisplay;
    procedure LoadBank(aName: string);
    procedure DisplayBank;
    procedure tbtLoadClick(Sender: TObject);
    procedure tbtNewClick(Sender: TObject);
    procedure tbtSaveAsClick(Sender: TObject);
    procedure tbtSaveClick(Sender: TObject);
  private

  public

  end;

var
  frmMain: TfrmMain;
  fBank: TDX7BankContainer;
  fVoice: TDX7VoiceContainer;
  fVoices: array [1..32] of TDX7VoiceContainer;
  sDragItem: string;
  iDragItemStart: integer;
  kpState: integer;
  HomeDir: string;
  lastBank: string;

implementation

{$R *.lfm}


{ TfrmMain }

procedure TfrmMain.stvClick(Sender: TObject); //Done
var
  sl: TStringList;
  i: integer;
begin
  sl := TStringList.Create;
  FindVCED_SYX((Sender as TShellTreeView).Path, sl);
  sgLeft.BeginUpdate;
  sgLeft.RowCount := 0;
  sgLeft.RowCount := sl.Count;
  for i := 0 to sl.Count - 1 do
  begin
    sgLeft.Cells[1, i] := sl[i];
  end;
  sgLeft.EndUpdate(True);
  StatusBar.Panels[0].Text := stvLeft.Path;
  sgLeft.Row := 0;
  sl.Free;
end;

procedure TfrmMain.sgLeftClick(Sender: TObject);  //Done
var
  msVoice: TMemoryStream;
  iStartPosition, iDmpPosition: integer;
begin
  if sgLeft.Row > -1 then
  begin
    if FileExists(IncludeTrailingPathDelimiter(stvLeft.Path) +
      sgLeft.Cells[1, sgLeft.Row]) then
    begin
      msVoice := TMemoryStream.Create;
      msVoice.LoadFromFile(IncludeTrailingPathDelimiter(stvLeft.Path) +
        sgLeft.Cells[1, sgLeft.Row]);
      iStartPosition := 0;
      iDmpPosition := 0;
      if ContainsDX7VoiceDump(msVoice, iStartPosition, iDmpPosition) then
      begin
        fVoice.Load_VCED_FromStream(msVoice, iDmpPosition);
        StatusBar.Panels[0].Text := fVoice.GetVoiceName;
      end;
      msVoice.Free;
    end;
  end;
end;

procedure TfrmMain.sgLeftDragDrop(Sender, Source: TObject; X, Y: integer);
var
  i, j: integer;
  msVoice: TMemoryStream;
  sName: string;
  sNewName: string;
begin
  Unused(Source, X, Y);
  for i := sgRight.Selection.Top to sgRight.Selection.Bottom do
  begin
    sName := IncludeTrailingPathDelimiter(stvLeft.Path) +
      GetValidFileName(sgRight.Cells[1, i]);
    j := 0;
    sNewName := sName;
    if FileExists(sNewName + '.syx') then
    begin
      while FileExists(sNewName + '.syx') do
      begin
        Inc(j);
        sNewName := sName + '_' + Format('%.4d', [j]);
      end;
    end;
    msVoice := TMemoryStream.Create;
    fVoices[i].SysExVoiceToStream(1, msVoice);
    msVoice.SaveToFile(IncludeTrailingPathDelimiter(stvLeft.Path) +
      sNewName + '.syx');
    msVoice.Free;
  end;
  sgRight.Row := 0;
  sgLeft.Selection := TGridRect(Rect(-1, -1, -1, -1));
end;

procedure TfrmMain.sgLeftDragOver(Sender, Source: TObject; X, Y: integer;
  State: TDragState; var Accept: boolean);
begin
  Unused(X, Y, State);
  if (Source = sgRight) and (iDragItemStart <> -1) then
    Accept := True
  else
    Accept := False;
end;

procedure TfrmMain.sgRightDragDrop(Sender, Source: TObject; X, Y: integer);
var
  iDestCol, iDestRow: integer;
  i: integer;
  msVoice: TMemoryStream;
  iStartPos, iDumpPos: integer;
  iDiff: integer;
begin
  (Sender as TStringGrid).MouseToCell(X, Y, iDestCol, iDestRow);
  if Source = sgLeft then   //Done
  begin
    if kpState = 1 then
    begin
      iDiff := Abs(sgLeft.Selection.Bottom - sgLeft.Selection.Top) + 1;
      for i := 32 downto (iDestRow + iDiff) do
      begin
        if (i - iDiff) > 0 then
        begin
          fVoices[i].Set_VCED_Params(fVoices[i - iDiff].Get_VCED_Params);
          fVoices[i - iDiff].SetVoiceName('Moved ' + IntToStr(i));
        end;
      end;
    end;
    for i := sgLeft.Selection.Top to sgLeft.Selection.Bottom do
    begin
      if iDestRow > 32 then Break;
      iStartPos := 0;
      iDumpPos := 0;
      if FileExists(IncludeTrailingPathDelimiter(stvLeft.Path) + sgLeft.Cells[1, i]) then
      begin
        msVoice := TMemoryStream.Create;
        msVoice.LoadFromFile(IncludeTrailingPathDelimiter(stvLeft.Path) +
          sgLeft.Cells[1, i]);
        if ContainsDX7VoiceDump(msVoice, iStartPos, iDumpPos) then
        begin
          fVoices[iDestRow].Load_VCED_FromStream(msVoice, iDumpPos);
          Inc(iDestRow);
        end;
        msVoice.Free;
      end;
    end;
  end;
  if Source = sgRight then
  begin
    if iDestRow = sgRight.Selection.Top then Exit;
    if kpState = 0 then
    begin
      for i := sgRight.Selection.Top to sgRight.Selection.Bottom do
      begin
        if iDestRow > 32 then Break;
        fVoices[iDestRow].Set_VCED_Params(fVoices[i + 1].Get_VCED_Params);
        fVoices[i + 1].InitVoice;
        Inc(iDestRow);
      end;
    end;
    if kpState = 1 then
    begin
      for i := sgRight.Selection.Top to sgRight.Selection.Bottom do
      begin
        if iDestRow > 32 then Break;
        fVoice.Set_VCED_Params(fVoices[iDestRow].Get_VCED_Params);
        fVoices[iDestRow].Set_VCED_Params(fVoices[i + 1].Get_VCED_Params);
        fVoices[i + 1].Set_VCED_Params(fVoice.Get_VCED_Params);
        Inc(iDestRow);
      end;
    end;
  end;
  DisplayBank;
  sgRight.Row := 0;
  sgLeft.Selection := TGridRect(Rect(-1, -1, -1, -1));
end;

procedure TfrmMain.sgRightDragOver(Sender, Source: TObject; X, Y: integer;
  State: TDragState; var Accept: boolean);  //Done
begin
  Unused(X, Y, State);
  if ((Source = sgLeft) or (Source = sgRight)) and (iDragItemStart <> -1) then
    Accept := True
  else
    Accept := False;
end;

procedure TfrmMain.sgRightEditingDone(Sender: TObject);  //Done
begin
  fVoices[sgRight.Row + 1].SetVoiceName(sgRight.Cells[1, sgRight.Row]);
  DisplayBank;
end;

procedure TfrmMain.sgSelection(Sender: TObject; aCol, aRow: integer);  //Done
begin
  Unused(aCol, aRow);
  iDragItemStart := (Sender as TStringGrid).Selection.Top;
end;

procedure TfrmMain.sgMouseDown(Sender: TObject; Button: TMouseButton;  //Done
  Shift: TShiftState; X, Y: integer);
var
  SourceCol: integer;
begin
  Unused(Shift, Button);
  (Sender as TStringGrid).MouseToCell(X, Y, SourceCol, iDragItemStart);
  if iDragItemStart > -1 then
  begin
    (Sender as TStringGrid).BeginDrag(False, 4);
  end;
end;

procedure TfrmMain.FormResize(Sender: TObject);  //Done
begin
  pnLeft.Width := (frmMain.Width div 2) - Splitter.Width;
  StatusBar.Panels[0].Width := pnLeft.Width - 75 + (Splitter.Width div 2);
  StatusBar.Panels[3].Width := pnRight.Width - 105 + (Splitter.Width div 2);
end;

procedure TfrmMain.FormCreate(Sender: TObject);  //Done
var
  ini: TIniFile;
  i: integer;
begin
  sDragItem := '';
  iDragItemStart := -1;
  fBank := TDX7BankContainer.Create;
  fVoice := TDX7VoiceContainer.Create;
  for i := 1 to 32 do
  begin
    fVoices[i] := TDX7VoiceContainer.Create;
    fVoices[i].InitVoice;
  end;
  DisplayBank;

  frmMain.KeyPreview := True;
  kpState := 0;
  kpDisplay;
  sgLeft.RowCount := 0;
  HomeDir := IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(GetUserDir) +
    'MiniDexedCC');
  if not DirectoryExists(HomeDir) then CreateDir(HomeDir);
  try
    ini := TIniFile.Create(HomeDir + 'BankManager.ini');
    if DirectoryExists(ini.ReadString('PanelLeft', 'LastDir', '')) then
    begin
      stvLeft.Path := ini.ReadString('PanelLeft', 'LastDir', '');
      stvClick(stvLeft);
    end;
    roLeft.Collapsed := ini.ReadBool('PanelLeft', 'RollOutCollapsed', False);
    if FileExists(ini.ReadString('PanelRight', 'LastFile', '')) then
    begin
      lastBank := ini.ReadString('PanelRight', 'LastFile', '');
      LoadBank(lastBank);
    end;
    roRight.Collapsed := ini.ReadBool('PanelRight', 'RollOutCollapsed', False);
    frmMain.Width := ini.ReadInteger('Form', 'Width', 1100);
    frmMain.Height := ini.ReadInteger('Form', 'Height', 784);
  finally
    ini.Free;
  end;
  Screen.Cursors[1] := LoadCursorFromLazarusResource('insert24');
  Screen.Cursors[2] := LoadCursorFromLazarusResource('overwrite24');
  Screen.Cursors[3] := LoadCursorFromLazarusResource('exchange24');
  if ParamCount > 0 then
  begin
    if DirectoryExists(ParamStr(1)) then
    begin
      stvLeft.Path := ParamStr(1);
      stvClick(stvLeft);
    end;
    if ParamCount = 2 then
      if FileExists(ParamStr(2)) then
      begin
        LoadBank(ParamStr(2));
        DisplayBank;
      end;
  end;
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: boolean); //Done
var
  ini: TIniFile;
  i: integer;
begin
  try
    ini := TIniFile.Create(HomeDir + 'BankManager.ini');
    ini.WriteString('PanelLeft', 'LastDir', stvLeft.Path);
    ini.WriteBool('PanelLeft', 'RollOutCollapsed', roLeft.Collapsed);
    ini.WriteString('PanelRight', 'LastFile', lastBank);
    ini.WriteBool('PanelRight', 'RollOutCollapsed', roRight.Collapsed);
    ini.WriteInteger('Form', 'Width', frmMain.Width);
    ini.WriteInteger('Form', 'Height', frmMain.Height);
  finally
    ini.Free;
  end;
  for i := 1 to 32 do
    fVoices[i].Free;
  fBank.Free;
  fVoice.Free;
  CanClose := True;
end;

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: word;
  Shift: TShiftState);   //Done
begin
  Unused(Key);
  if ssCtrl in Shift then kpState := 1
  else
    kpState := 0;
  kpDisplay;
end;

procedure TfrmMain.FormKeyUp(Sender: TObject; var Key: word;
  Shift: TShiftState);    //Done
begin
  Unused(Key);
  if ssCtrl in Shift then kpState := 1
  else
    kpState := 0;
  kpDisplay;
end;

procedure TfrmMain.kpDisplay;    //Done
begin
  case kpState of
    0: begin
      StatusBar.Panels[1].Text := 'OVERWRITE';
      StatusBar.Panels[2].Text := 'OVERWRITE';
      sgLeft.DragCursor := 2;
      sgRight.DragCursor := 2;
    end;
    1: begin  //Shift
      StatusBar.Panels[1].Text := 'INSERT';
      StatusBar.Panels[2].Text := 'EXCHANGE';
      sgLeft.DragCursor := 1;
      sgRight.DragCursor := 3;
    end;
  end;
end;

procedure TfrmMain.DisplayBank;  //Done
var
  i: integer;
begin
  for i := 1 to 32 do
  begin
    sgRight.Cells[1, i - 1] := fVoices[i].GetVoiceName;
  end;
end;

procedure TfrmMain.LoadBank(aName: string);
var
  msBank: TMemoryStream;
  i: integer;
  iStartPos, iDumpPos: integer;
begin
  if FileSize(aName) = 4104 then
  begin
    iStartPos := 0;
    iDumpPos := 0;
    msBank := TMemoryStream.Create;
    msBank.LoadFromFile(aName);
    if ContainsDX7BankDump(msBank, iStartPos, iDumpPos) then
    begin
      fBank.LoadBankFromStream(msBank, iDumpPos);
      for i := 1 to 32 do
      begin
        fBank.GetVoice(i, fVoices[i]);
      end;
      tbtSave.Enabled := True;
      lastBank := aName;
      DisplayBank;
      StatusBar.Panels[3].Text := ExtractFileName(lastBank);
    end
    else
      PopUp('Not a DX7 VMEM file', 2);
    msBank.Free;
  end
  else
    PopUp('File size is not 4101 bytes', 2);
end;

procedure TfrmMain.tbtLoadClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    LoadBank(OpenDialog1.FileName);
end;

procedure TfrmMain.tbtNewClick(Sender: TObject);
var
  i: integer;
begin
  lastBank := '';
  tbtSave.Enabled := False;
  for i := 1 to 32 do
  begin
    fVoices[i].InitVoice;
  end;
  DisplayBank;
end;

procedure TfrmMain.tbtSaveAsClick(Sender: TObject);
var
  i: integer;
begin
  if SaveDialog1.Execute then
  begin
    for i := 1 to 32 do
      fBank.SetVoice(i, fVoices[i]);
    if fBank.SaveBankToSysExFile(SaveDialog1.FileName) then
    begin
      PopUp('Saved', 2);
      tbtSave.Enabled := True;
      lastBank := SaveDialog1.FileName;
      StatusBar.Panels[3].Text := ExtractFileName(lastBank);
    end
    else
      PopUp('Could not save', 2);
  end;
end;

procedure TfrmMain.tbtSaveClick(Sender: TObject);
var
  i: integer;
begin
  if (lastBank <> '') and FileExists(lastBank) then
  begin
    for i := 1 to 32 do
      fBank.SetVoice(i, fVoices[i]);
    if fBank.SaveBankToSysExFile(lastBank) then
    begin
      PopUp('Saved', 2);
    end
    else
      PopUp('Could not save', 2);
  end
  else
    tbtSaveAsClick(self);
end;

initialization
{$I cursors.lrs}

end.
