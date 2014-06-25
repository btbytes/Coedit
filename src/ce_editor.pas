unit ce_editor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, ExtendedNotebook, Forms, Controls,
  Graphics, SynEditKeyCmds, ComCtrls, SynEditHighlighter, ExtCtrls, Menus,
  SynEditHighlighterFoldBase, SynMacroRecorder, SynPluginSyncroEdit, SynEdit,
  SynHighlighterLFM, ce_widget, ce_d2syn, ce_synmemo, ce_common;

type
  { TCEEditorWidget }
  TCEEditorWidget = class(TCEWidget)
    imgList: TImageList;
    PageControl: TExtendedNotebook;
    macRecorder: TSynMacroRecorder;
    editorStatus: TStatusBar;
    procedure PageControlChange(Sender: TObject);
    procedure PageControlCloseTabClicked(Sender: TObject);
  protected
    procedure UpdateByDelay; override;
  private
    // http://bugs.freepascal.org/view.php?id=26329
    fKeyChanged: boolean;
    fSyncEdit: TSynPluginSyncroEdit;
    procedure memoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure memoMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure memoChange(Sender: TObject);
    procedure memoMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    function getCurrentEditor: TCESynMemo;
    function getEditor(index: NativeInt): TCESynMemo;
    function getEditorCount: NativeInt;
    function getEditorIndex: NativeInt;
    procedure identifierToD2Syn(const aMemo: TCESynMemo);
  public
    constructor create(aOwner: TComponent); override;
    procedure addEditor;
    procedure removeEditor(const aIndex: NativeInt);
    procedure focusedEditorChanged;
    //
    property currentEditor: TCESynMemo read getCurrentEditor;
    property editor[index: NativeInt]: TCESynMemo read getEditor;
    property editorCount: NativeInt read getEditorCount;
    property editorIndex: NativeInt read getEditorIndex;
  end;

implementation
{$R *.lfm}

uses
  ce_main;

constructor TCEEditorWidget.create(aOwner: TComponent);
var
  bmp: TBitmap;
begin
  inherited;
  fID := 'ID_EDIT';
  fSyncEdit := TSynPluginSyncroEdit.Create(self);
  bmp := TBitmap.Create;
  try
    imgList.GetBitmap(0,bmp);
    fSyncEdit.GutterGlyph.Assign(bmp);
  finally
    bmp.Free;
  end;
end;

function TCEEditorWidget.getEditorCount: NativeInt;
begin
  result := pageControl.PageCount;
end;

function TCEEditorWidget.getEditorIndex: NativeInt;
begin
  if pageControl.PageCount > 0 then
    result := pageControl.PageIndex
  else result := -1;
end;

function TCEEditorWidget.getCurrentEditor: TCESynMemo;
begin
  if pageControl.PageCount = 0 then result := nil
  else result := TCESynMemo(pageControl.ActivePage.Controls[0]);
end;

function TCEEditorWidget.getEditor(index: NativeInt): TCESynMemo;
begin
  result := TCESynMemo(pageControl.Pages[index].Controls[0]);
end;

procedure TCEEditorWidget.focusedEditorChanged;
var
  curr: TCESynMemo;
  md: string;
begin
  curr := getCurrentEditor;
  macRecorder.Editor := curr;
  fSyncEdit.Editor := curr;
  identifierToD2Syn(curr);
  md := getModuleName(curr.Lines);
  if md = '' then md := extractFileName(curr.fileName);
  pageControl.ActivePage.Caption := md;
  //
  if pageControl.ActivePageIndex <> -1 then
    mainForm.docFocusedNotify(Self, pageControl.ActivePageIndex);
end;

procedure TCEEditorWidget.PageControlChange(Sender: TObject);
begin
  //http://bugs.freepascal.org/view.php?id=26320
  focusedEditorChanged;
end;

procedure TCEEditorWidget.PageControlCloseTabClicked(Sender: TObject);
begin
  // closeBtn not implemented
  mainForm.actFileClose.Execute;
end;

procedure TCEEditorWidget.addEditor;
var
  sheet: TTabSheet;
  memo: TCESynMemo;
begin
  sheet := pageControl.AddTabSheet;
  memo  := TCESynMemo.Create(sheet);
  //
  memo.Align:=alClient;
  memo.Parent := sheet;
  //
  memo.OnKeyDown := @memoKeyDown;
  memo.OnKeyUp := @memoKeyDown;
  memo.OnMouseDown := @memoMouseDown;
  memo.OnChange := @memoChange;
  memo.OnMouseMove := @memoMouseMove;
  //
  pageControl.ActivePage := sheet;
  //http://bugs.freepascal.org/view.php?id=26320
  focusedEditorChanged;
end;

procedure TCEEditorWidget.removeEditor(const aIndex: NativeInt);
begin
  editor[aIndex].OnChange:= nil;
  pageControl.Pages[aIndex].Free;
end;

procedure TCEEditorWidget.identifierToD2Syn(const aMemo: TCESynMemo);
begin
  D2Syn.CurrentIdentifier := aMemo.GetWordAtRowCol(aMemo.LogicalCaretXY);
end;

procedure TCEEditorWidget.memoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (sender is TCESynMemo) then
    identifierToD2Syn(TCESynMemo(Sender));
  fKeyChanged := true;
  beginUpdateByDelay;
end;

procedure TCEEditorWidget.memoMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (sender is TCESynMemo) then
    identifierToD2Syn(TCESynMemo(Sender));
  beginUpdateByDelay;
end;

procedure TCEEditorWidget.memoMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if ssLeft in Shift then
    beginUpdateByDelay;
end;

procedure TCEEditorWidget.memoChange(Sender: TObject);
var
  ed: TCESynMemo;
begin
  ed := TCESynMemo(sender);
  ed.modified := true;
  beginUpdateByDelay;
end;

procedure TCEEditorWidget.UpdateByDelay;
const
  modstr: array[boolean] of string = ('...', 'MODIFIED');
var
  ed: TCESynMemo;
begin
  ed := getCurrentEditor;
  if ed <> nil then
  begin
    editorStatus.Panels[0].Text := format('%d : %d',[ed.CaretY, ed.CaretX]);
    editorStatus.Panels[1].Text := modstr[ed.modified];
    editorStatus.Panels[2].Text := ed.fileName;
  end;
  //
  if fKeyChanged then if editorIndex <> -1 then
    mainForm.docChangeNotify(Self, editorIndex);
  fKeyChanged := false;
end;

end.
