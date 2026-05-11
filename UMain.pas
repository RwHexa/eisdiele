unit UMain;

{
  Eisdiele Kasse - TMS Web Core - V3 ohne Generics
  ------------------------------------------------
  Generics raus (pas2js Trial bricht JS-Output bei TObjectList<T> ab).
  Statt TObjectList<T> -> dynamische Arrays of T.
  Speicher-Freigabe manuell, aber bei dieser App ueberschaubar.
}

interface

uses
  System.SysUtils, System.Classes, JS, Web,
  WEBLib.Graphics, WEBLib.Controls, WEBLib.Forms, WEBLib.Dialogs,
  WEBLib.StdCtrls, WEBLib.ExtCtrls;

type
  TConsumeMode = (cmTakeAway, cmEatHere);

  TProduct = class
  public
    Id   : Integer;
    Cat  : string;
    Nm   : string;
    Pr   : Double;
    Ico  : string;
    Vat19: Boolean;
    constructor Create(AId: Integer; const ACat, ANm: string; APr: Double;
      const AIco: string; AVat19: Boolean = False);
  end;

  TOrderItem = class
  public
    Product: TProduct;
    Qty    : Integer;
  end;

  TOrderItemArray = array of TOrderItem;
  TProductArray   = array of TProduct;

  TTable = class
  public
    Id   : string;
    Name : string;
    Mode : TConsumeMode;
    Items: TOrderItemArray;
    constructor Create(const AId, AName: string; AMode: TConsumeMode);
    destructor Destroy; override;
    function GrossTotal: Double;
    function IsBusy: Boolean;
    function ItemCount: Integer;
    procedure ClearItems;
    procedure AddItem(AItem: TOrderItem);
    procedure RemoveItemAt(Idx: Integer);
  end;

  TTableArray = array of TTable;

  TForm1 = class(TWebForm)
    procedure WebFormCreate(Sender: TObject);
    procedure WebFormDestroy(Sender: TObject);
  private
    FProducts   : TProductArray;
    FTables     : TTableArray;
    FActiveTable: TTable;
    FCategories : TStringList;
    FActiveCat  : string;

    pnlRoot, pnlTop, pnlTables, pnlMain, pnlLeft, pnlCart: TWebPanel;
    pnlCats, pnlTiles, pnlLines, pnlTotals, pnlActions: TWebPanel;

    lblShop, lblActiveTable: TWebLabel;
    btnTake, btnHere: TWebButton;

    lblCartHeader: TWebLabel;
    lblNet, lblVat, lblTotal, lblVatLabel: TWebLabel;

    btnCancel, btnCard, btnCash: TWebButton;

    procedure SeedProducts;
    procedure SeedTables;
    procedure BuildUI;
    procedure RebuildTables;
    procedure RebuildCategories;
    procedure RebuildTiles;
    procedure RefreshCart;
    procedure UpdateModeButtons;
    procedure AddToActiveTable(AProduct: TProduct);

    procedure ClearPanel(APanel: TWebPanel);
    procedure FreeProducts;
    procedure FreeTables;
    procedure AddProduct(AProd: TProduct);
    procedure AddTable(ATable: TTable);

    procedure TableClick(Sender: TObject);
    procedure CategoryClick(Sender: TObject);
    procedure TileClick(Sender: TObject);
    procedure RemoveLineClick(Sender: TObject);
    procedure TakeAwayClick(Sender: TObject);
    procedure EatHereClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure CashClick(Sender: TObject);
    procedure CardClick(Sender: TObject);

    function FmtMoney(V: Double): string;
    function FindProduct(AId: Integer): TProduct;
    function FindTable(const AId: string): TTable;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

{ TProduct }

constructor TProduct.Create(AId: Integer; const ACat, ANm: string; APr: Double;
  const AIco: string; AVat19: Boolean);
begin
  inherited Create;
  Id := AId; Cat := ACat; Nm := ANm; Pr := APr; Ico := AIco; Vat19 := AVat19;
end;

{ TTable }

constructor TTable.Create(const AId, AName: string; AMode: TConsumeMode);
begin
  inherited Create;
  Id := AId; Name := AName; Mode := AMode;
  SetLength(Items, 0);
end;

destructor TTable.Destroy;
begin
  ClearItems;
  inherited;
end;

function TTable.GrossTotal: Double;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Length(Items) - 1 do
    Result := Result + Items[I].Product.Pr * Items[I].Qty;
end;

function TTable.IsBusy: Boolean;
begin
  Result := Length(Items) > 0;
end;

function TTable.ItemCount: Integer;
begin
  Result := Length(Items);
end;

procedure TTable.ClearItems;
var
  I: Integer;
begin
  for I := 0 to Length(Items) - 1 do
    Items[I].Free;
  SetLength(Items, 0);
end;

procedure TTable.AddItem(AItem: TOrderItem);
var
  N: Integer;
begin
  N := Length(Items);
  SetLength(Items, N + 1);
  Items[N] := AItem;
end;

procedure TTable.RemoveItemAt(Idx: Integer);
var
  I, N: Integer;
begin
  N := Length(Items);
  if (Idx < 0) or (Idx >= N) then Exit;
  Items[Idx].Free;
  for I := Idx to N - 2 do
    Items[I] := Items[I + 1];
  SetLength(Items, N - 1);
end;

{ TForm1 }

procedure TForm1.ClearPanel(APanel: TWebPanel);
var
  Idx: Integer;
  C: TControl;
begin
  for Idx := APanel.ControlCount - 1 downto 0 do
  begin
    C := APanel.Controls[Idx];
    C.Free;
  end;
end;

procedure TForm1.FreeProducts;
var
  I: Integer;
begin
  for I := 0 to Length(FProducts) - 1 do
    FProducts[I].Free;
  SetLength(FProducts, 0);
end;

procedure TForm1.FreeTables;
var
  I: Integer;
begin
  for I := 0 to Length(FTables) - 1 do
    FTables[I].Free;
  SetLength(FTables, 0);
end;

procedure TForm1.AddProduct(AProd: TProduct);
var
  N: Integer;
begin
  N := Length(FProducts);
  SetLength(FProducts, N + 1);
  FProducts[N] := AProd;
end;

procedure TForm1.AddTable(ATable: TTable);
var
  N: Integer;
begin
  N := Length(FTables);
  SetLength(FTables, N + 1);
  FTables[N] := ATable;
end;

function TForm1.FmtMoney(V: Double): string;
begin
  Result := StringReplace(FormatFloat('0.00', V), '.', ',', []) + ' €';
end;

function TForm1.FindProduct(AId: Integer): TProduct;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Length(FProducts) - 1 do
    if FProducts[I].Id = AId then
    begin
      Result := FProducts[I];
      Exit;
    end;
end;

function TForm1.FindTable(const AId: string): TTable;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Length(FTables) - 1 do
    if FTables[I].Id = AId then
    begin
      Result := FTables[I];
      Exit;
    end;
end;

procedure TForm1.WebFormCreate(Sender: TObject);
begin
  SetLength(FProducts, 0);
  SetLength(FTables, 0);
  FCategories := TStringList.Create;
  FActiveCat  := 'Eis';

  SeedProducts;
  SeedTables;
  FActiveTable := FTables[0];

  BuildUI;
  RebuildTables;
  RebuildCategories;
  RebuildTiles;
  UpdateModeButtons;
  RefreshCart;
end;

procedure TForm1.WebFormDestroy(Sender: TObject);
begin
  FreeTables;
  FreeProducts;
  FCategories.Free;
end;

procedure TForm1.SeedProducts;
begin
  AddProduct(TProduct.Create( 1, 'Eis',     'Vanille',       1.50, '🍦'));
  AddProduct(TProduct.Create( 2, 'Eis',     'Schoko',        1.50, '🍫'));
  AddProduct(TProduct.Create( 3, 'Eis',     'Erdbeere',      1.50, '🍓'));
  AddProduct(TProduct.Create( 4, 'Eis',     'Pistazie',      1.70, '🌰'));
  AddProduct(TProduct.Create( 5, 'Eis',     'Stracciatella', 1.50, '🍨'));
  AddProduct(TProduct.Create( 6, 'Eis',     'Zitrone',       1.50, '🍋'));
  AddProduct(TProduct.Create( 7, 'Eis',     'Mango',         1.70, '🥭'));
  AddProduct(TProduct.Create( 8, 'Eis',     'Haselnuss',     1.50, '🌰'));
  AddProduct(TProduct.Create(10, 'Becher',  'Spaghetti-Eis', 6.50, '🍝'));
  AddProduct(TProduct.Create(11, 'Becher',  'Bananensplit',  5.90, '🍌'));
  AddProduct(TProduct.Create(12, 'Becher',  'Becher Sahne',  4.50, '🍨'));
  AddProduct(TProduct.Create(13, 'Becher',  'Heisse Liebe',  5.50, '❤'));
  AddProduct(TProduct.Create(20, 'Waffel',  'Waffel + Eis',  4.50, '🧇'));
  AddProduct(TProduct.Create(21, 'Waffel',  'Waffel Sahne',  3.50, '🧇'));
  AddProduct(TProduct.Create(30, 'Getränk', 'Espresso',      2.20, '☕', True));
  AddProduct(TProduct.Create(31, 'Getränk', 'Cappuccino',    3.20, '☕', True));
  AddProduct(TProduct.Create(32, 'Getränk', 'Wasser',        2.50, '💧', True));
  AddProduct(TProduct.Create(33, 'Getränk', 'Cola',          2.80, '🥤', True));

  FCategories.Clear;
  FCategories.Add('Eis');
  FCategories.Add('Becher');
  FCategories.Add('Waffel');
  FCategories.Add('Getränk');
end;

procedure TForm1.SeedTables;
var
  I: Integer;
begin
  for I := 1 to 8 do
    AddTable(TTable.Create('t' + IntToStr(I), 'Tisch ' + IntToStr(I), cmEatHere));
  AddTable(TTable.Create('th', 'Theke',    cmTakeAway));
  AddTable(TTable.Create('mn', 'Mitnahme', cmTakeAway));
end;

procedure TForm1.BuildUI;
var
  rowNet, rowVat, rowSum: TWebPanel;
  lN1, lS1: TWebLabel;
begin
  pnlRoot := TWebPanel.Create(Self);
  pnlRoot.ElementPosition := epIgnore;
  pnlRoot.ElementFont := efCSS;
  pnlRoot.Parent := Self;
  pnlRoot.ElementClassName := 'kasse-root';

  pnlTop := TWebPanel.Create(Self);

  pnlTop.ElementPosition := epIgnore;

  pnlTop.ElementFont := efCSS;
  pnlTop.Parent := pnlRoot;
  pnlTop.ElementClassName := 'topbar';

  lblShop := TWebLabel.Create(Self);

  lblShop.ElementPosition := epIgnore;

  lblShop.ElementFont := efCSS;
  lblShop.Parent := pnlTop;
  lblShop.Caption := '🍦 Eisdiele Bella';
  lblShop.ElementClassName := 'shop';

  lblActiveTable := TWebLabel.Create(Self);

  lblActiveTable.ElementPosition := epIgnore;

  lblActiveTable.ElementFont := efCSS;
  lblActiveTable.Parent := pnlTop;
  lblActiveTable.Caption := 'aktiv: Tisch 1';
  lblActiveTable.ElementClassName := 'active-table';

  btnTake := TWebButton.Create(Self);

  btnTake.ElementPosition := epIgnore;

  btnTake.ElementFont := efCSS;
  btnTake.Parent := pnlTop;
  btnTake.Caption := 'Mitnahme · 7%';
  btnTake.ElementClassName := 'mode-btn';
  btnTake.OnClick := TakeAwayClick;

  btnHere := TWebButton.Create(Self);

  btnHere.ElementPosition := epIgnore;

  btnHere.ElementFont := efCSS;
  btnHere.Parent := pnlTop;
  btnHere.Caption := 'Vor Ort · 19%';
  btnHere.ElementClassName := 'mode-btn';
  btnHere.OnClick := EatHereClick;

  pnlTables := TWebPanel.Create(Self);

  pnlTables.ElementPosition := epIgnore;

  pnlTables.ElementFont := efCSS;
  pnlTables.Parent := pnlRoot;
  pnlTables.ElementClassName := 'tables';

  pnlMain := TWebPanel.Create(Self);

  pnlMain.ElementPosition := epIgnore;

  pnlMain.ElementFont := efCSS;
  pnlMain.Parent := pnlRoot;
  pnlMain.ElementClassName := 'main';

  pnlLeft := TWebPanel.Create(Self);

  pnlLeft.ElementPosition := epIgnore;

  pnlLeft.ElementFont := efCSS;
  pnlLeft.Parent := pnlMain;
  pnlLeft.ElementClassName := 'left';

  pnlCats := TWebPanel.Create(Self);

  pnlCats.ElementPosition := epIgnore;

  pnlCats.ElementFont := efCSS;
  pnlCats.Parent := pnlLeft;
  pnlCats.ElementClassName := 'cats';

  pnlTiles := TWebPanel.Create(Self);

  pnlTiles.ElementPosition := epIgnore;

  pnlTiles.ElementFont := efCSS;
  pnlTiles.Parent := pnlLeft;
  pnlTiles.ElementClassName := 'tiles';

  pnlCart := TWebPanel.Create(Self);

  pnlCart.ElementPosition := epIgnore;

  pnlCart.ElementFont := efCSS;
  pnlCart.Parent := pnlMain;
  pnlCart.ElementClassName := 'cart';

  lblCartHeader := TWebLabel.Create(Self);

  lblCartHeader.ElementPosition := epIgnore;

  lblCartHeader.ElementFont := efCSS;
  lblCartHeader.Parent := pnlCart;
  lblCartHeader.Caption := 'Bestellung – Tisch 1';
  lblCartHeader.ElementClassName := 'cart-header';

  pnlLines := TWebPanel.Create(Self);

  pnlLines.ElementPosition := epIgnore;

  pnlLines.ElementFont := efCSS;
  pnlLines.Parent := pnlCart;
  pnlLines.ElementClassName := 'lines';

  pnlTotals := TWebPanel.Create(Self);

  pnlTotals.ElementPosition := epIgnore;

  pnlTotals.ElementFont := efCSS;
  pnlTotals.Parent := pnlCart;
  pnlTotals.ElementClassName := 'totals';

  rowNet := TWebPanel.Create(Self);

  rowNet.ElementPosition := epIgnore;

  rowNet.ElementFont := efCSS;
  rowNet.Parent := pnlTotals; rowNet.ElementClassName := 'row';
  lN1 := TWebLabel.Create(Self); lN1.Parent := rowNet; lN1.Caption := 'Netto';
  lblNet := TWebLabel.Create(Self); lblNet.Parent := rowNet;
  lblNet.Caption := '0,00 €'; lblNet.ElementClassName := 'val';

  rowVat := TWebPanel.Create(Self);

  rowVat.ElementPosition := epIgnore;

  rowVat.ElementFont := efCSS;
  rowVat.Parent := pnlTotals; rowVat.ElementClassName := 'row';
  lblVatLabel := TWebLabel.Create(Self); lblVatLabel.Parent := rowVat;
  lblVatLabel.Caption := 'MwSt 19%';
  lblVat := TWebLabel.Create(Self); lblVat.Parent := rowVat;
  lblVat.Caption := '0,00 €'; lblVat.ElementClassName := 'val';

  rowSum := TWebPanel.Create(Self);

  rowSum.ElementPosition := epIgnore;

  rowSum.ElementFont := efCSS;
  rowSum.Parent := pnlTotals; rowSum.ElementClassName := 'row sum';
  lS1 := TWebLabel.Create(Self); lS1.Parent := rowSum; lS1.Caption := 'Tischsumme';
  lblTotal := TWebLabel.Create(Self); lblTotal.Parent := rowSum;
  lblTotal.Caption := '0,00 €'; lblTotal.ElementClassName := 'val';

  pnlActions := TWebPanel.Create(Self);

  pnlActions.ElementPosition := epIgnore;

  pnlActions.ElementFont := efCSS;
  pnlActions.Parent := pnlCart;
  pnlActions.ElementClassName := 'actions';

  btnCancel := TWebButton.Create(Self);

  btnCancel.ElementPosition := epIgnore;

  btnCancel.ElementFont := efCSS;
  btnCancel.Parent := pnlActions;
  btnCancel.Caption := 'Storno';
  btnCancel.ElementClassName := 'act cancel';
  btnCancel.OnClick := CancelClick;

  btnCard := TWebButton.Create(Self);

  btnCard.ElementPosition := epIgnore;

  btnCard.ElementFont := efCSS;
  btnCard.Parent := pnlActions;
  btnCard.Caption := 'Karte';
  btnCard.ElementClassName := 'act';
  btnCard.OnClick := CardClick;

  btnCash := TWebButton.Create(Self);

  btnCash.ElementPosition := epIgnore;

  btnCash.ElementFont := efCSS;
  btnCash.Parent := pnlActions;
  btnCash.Caption := 'Bar kassieren';
  btnCash.ElementClassName := 'act pay';
  btnCash.OnClick := CashClick;
end;

procedure TForm1.RebuildTables;
var
  I: Integer;
  T: TTable;
  Btn: TWebButton;
  Cls, Sum: string;
begin
  ClearPanel(pnlTables);

  for I := 0 to Length(FTables) - 1 do
  begin
    T := FTables[I];
    Btn := TWebButton.Create(Self);
    Btn.ElementPosition := epIgnore;
    Btn.ElementFont := efCSS;
    Btn.Parent := pnlTables;
    Btn.ElementID := 'tbl_' + T.Id;
    Btn.OnClick := TableClick;

    if T = FActiveTable then Cls := 'tbtn on'
    else if T.IsBusy then Cls := 'tbtn busy'
    else Cls := 'tbtn';
    Btn.ElementClassName := Cls;

    if T.IsBusy then Sum := FmtMoney(T.GrossTotal) else Sum := '–';
    Btn.Caption := T.Name + #10 + Sum;
  end;
end;

procedure TForm1.RebuildCategories;
var
  I: Integer;
  Btn: TWebButton;
begin
  ClearPanel(pnlCats);

  for I := 0 to FCategories.Count - 1 do
  begin
    Btn := TWebButton.Create(Self);
    Btn.ElementPosition := epIgnore;
    Btn.ElementFont := efCSS;
    Btn.Parent := pnlCats;
    Btn.Caption := FCategories[I];
    Btn.Tag := I;
    if FCategories[I] = FActiveCat then
      Btn.ElementClassName := 'cat-btn on'
    else
      Btn.ElementClassName := 'cat-btn';
    Btn.OnClick := CategoryClick;
  end;
end;

procedure TForm1.RebuildTiles;
var
  I: Integer;
  P: TProduct;
  Btn: TWebButton;
begin
  ClearPanel(pnlTiles);

  for I := 0 to Length(FProducts) - 1 do
  begin
    P := FProducts[I];
    if P.Cat <> FActiveCat then Continue;

    Btn := TWebButton.Create(Self);

    Btn.ElementPosition := epIgnore;

    Btn.ElementFont := efCSS;
    Btn.Parent := pnlTiles;
    Btn.ElementClassName := 'tile';
    Btn.Tag := P.Id;
    Btn.OnClick := TileClick;
    Btn.Caption := P.Ico + #10 + P.Nm + #10 + FmtMoney(P.Pr);
  end;
end;

procedure TForm1.RefreshCart;
var
  I: Integer;
  Item: TOrderItem;
  LinePnl: TWebPanel;
  LblQty, LblName, LblPrice, LblEmpty: TWebLabel;
  BtnRm: TWebButton;
  Gross, Net, Vat, R, LineGross, LineNet, VatRate: Double;
begin
  lblActiveTable.Caption := 'aktiv: ' + FActiveTable.Name;
  lblCartHeader.Caption  := 'Bestellung – ' + FActiveTable.Name;

  ClearPanel(pnlLines);

  if FActiveTable.ItemCount = 0 then
  begin
    LblEmpty := TWebLabel.Create(Self);
    LblEmpty.ElementPosition := epIgnore;
    LblEmpty.ElementFont := efCSS;
    LblEmpty.Parent := pnlLines;
    LblEmpty.Caption := 'Noch nichts ausgewählt';
    LblEmpty.ElementClassName := 'empty';
  end
  else
  begin
    for I := 0 to FActiveTable.ItemCount - 1 do
    begin
      Item := FActiveTable.Items[I];

      LinePnl := TWebPanel.Create(Self);

      LinePnl.ElementPosition := epIgnore;

      LinePnl.ElementFont := efCSS;
      LinePnl.Parent := pnlLines;
      LinePnl.ElementClassName := 'line';

      LblQty := TWebLabel.Create(Self);

      LblQty.ElementPosition := epIgnore;

      LblQty.ElementFont := efCSS;
      LblQty.Parent := LinePnl;
      LblQty.Caption := IntToStr(Item.Qty) + '×';
      LblQty.ElementClassName := 'qty';

      LblName := TWebLabel.Create(Self);

      LblName.ElementPosition := epIgnore;

      LblName.ElementFont := efCSS;
      LblName.Parent := LinePnl;
      LblName.Caption := Item.Product.Nm;
      LblName.ElementClassName := 'nm';

      LblPrice := TWebLabel.Create(Self);

      LblPrice.ElementPosition := epIgnore;

      LblPrice.ElementFont := efCSS;
      LblPrice.Parent := LinePnl;
      LblPrice.Caption := FmtMoney(Item.Product.Pr * Item.Qty);
      LblPrice.ElementClassName := 'pr';

      BtnRm := TWebButton.Create(Self);

      BtnRm.ElementPosition := epIgnore;

      BtnRm.ElementFont := efCSS;
      BtnRm.Parent := LinePnl;
      BtnRm.Caption := '×';
      BtnRm.ElementClassName := 'rm';
      BtnRm.Tag := I;
      BtnRm.OnClick := RemoveLineClick;
    end;
  end;

  Gross := 0; Net := 0; Vat := 0;
  if FActiveTable.Mode = cmTakeAway then VatRate := 0.07 else VatRate := 0.19;

  for I := 0 to FActiveTable.ItemCount - 1 do
  begin
    Item := FActiveTable.Items[I];
    if Item.Product.Vat19 then R := 0.19 else R := VatRate;
    LineGross := Item.Product.Pr * Item.Qty;
    LineNet   := LineGross / (1 + R);
    Gross := Gross + LineGross;
    Net   := Net + LineNet;
    Vat   := Vat + (LineGross - LineNet);
  end;

  lblNet.Caption   := FmtMoney(Net);
  lblVat.Caption   := FmtMoney(Vat);
  lblTotal.Caption := FmtMoney(Gross);

  if FActiveTable.Mode = cmTakeAway then
    lblVatLabel.Caption := 'MwSt 7% / 19%'
  else
    lblVatLabel.Caption := 'MwSt 19%';
end;

procedure TForm1.UpdateModeButtons;
begin
  if FActiveTable.Mode = cmTakeAway then
  begin
    btnTake.ElementClassName := 'mode-btn on';
    btnHere.ElementClassName := 'mode-btn';
  end
  else
  begin
    btnTake.ElementClassName := 'mode-btn';
    btnHere.ElementClassName := 'mode-btn on';
  end;
end;

procedure TForm1.AddToActiveTable(AProduct: TProduct);
var
  I: Integer;
  Item: TOrderItem;
begin
  for I := 0 to FActiveTable.ItemCount - 1 do
    if FActiveTable.Items[I].Product = AProduct then
    begin
      FActiveTable.Items[I].Qty := FActiveTable.Items[I].Qty + 1;
      RefreshCart;
      RebuildTables;
      Exit;
    end;

  Item := TOrderItem.Create;
  Item.Product := AProduct;
  Item.Qty := 1;
  FActiveTable.AddItem(Item);
  RefreshCart;
  RebuildTables;
end;

procedure TForm1.TableClick(Sender: TObject);
var
  Btn: TWebButton;
  TblId: string;
  T: TTable;
begin
  Btn := Sender as TWebButton;
  TblId := Copy(Btn.ElementID, 5, MaxInt);
  T := FindTable(TblId);
  if Assigned(T) then
  begin
    FActiveTable := T;
    RebuildTables;
    UpdateModeButtons;
    RefreshCart;
  end;
end;

procedure TForm1.CategoryClick(Sender: TObject);
begin
  FActiveCat := FCategories[(Sender as TWebButton).Tag];
  RebuildCategories;
  RebuildTiles;
end;

procedure TForm1.TileClick(Sender: TObject);
var
  P: TProduct;
begin
  P := FindProduct((Sender as TWebButton).Tag);
  if Assigned(P) then AddToActiveTable(P);
end;

procedure TForm1.RemoveLineClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := (Sender as TWebButton).Tag;
  if (Idx >= 0) and (Idx < FActiveTable.ItemCount) then
  begin
    FActiveTable.RemoveItemAt(Idx);
    RefreshCart;
    RebuildTables;
  end;
end;

procedure TForm1.TakeAwayClick(Sender: TObject);
begin
  FActiveTable.Mode := cmTakeAway;
  UpdateModeButtons;
  RefreshCart;
end;

procedure TForm1.EatHereClick(Sender: TObject);
begin
  FActiveTable.Mode := cmEatHere;
  UpdateModeButtons;
  RefreshCart;
end;

procedure TForm1.CancelClick(Sender: TObject);
begin
  FActiveTable.ClearItems;
  RefreshCart;
  RebuildTables;
end;

procedure TForm1.CashClick(Sender: TObject);
begin
  if FActiveTable.ItemCount = 0 then Exit;
  ShowMessage('Bar kassiert für ' + FActiveTable.Name + ': ' + lblTotal.Caption);
  FActiveTable.ClearItems;
  RefreshCart;
  RebuildTables;
end;

procedure TForm1.CardClick(Sender: TObject);
begin
  if FActiveTable.ItemCount = 0 then Exit;
  ShowMessage('Karte für ' + FActiveTable.Name + ': ' + lblTotal.Caption);
  FActiveTable.ClearItems;
  RefreshCart;
  RebuildTables;
end;

end.
